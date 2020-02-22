#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libpq-fe.h>
#include "postgres-driver.h"

int starts_with(const char *pre, const char *str) {
    size_t lenpre = strlen(pre),
           lenstr = strlen(str);
    return lenstr < lenpre ? 0 : (memcmp(pre, str, lenpre) == 0 ? 1 : 0);
}

PGconn* open_connection(char* connection_string) {
    PGconn* conn = PQconnectdb(connection_string);

    if (PQstatus(conn) == CONNECTION_BAD) {
        printf("Connection to database failed: %s\n", PQerrorMessage(conn));
        PQfinish(conn);
        return NULL;
    }

    return conn;
}

ResultSet* perform_query(PGconn* conn, char* query, int paramCount, const char * const* paramValues, int reconnect) {
    PGresult *res;

    ResultSet* resultSet = (ResultSet*)malloc(sizeof(ResultSet));
    resultSet->res = NULL;
    resultSet->error = NULL;
    resultSet->columnsNumber = 0;
    resultSet->columnNames = NULL;
    resultSet->rowsNumber = 0;
    resultSet->rows = NULL;

    if (PQstatus(conn) == CONNECTION_BAD) {
        printf("Connection is bad, trying to recover ...\n");
        PQreset(conn);
      if (PQstatus(conn) == CONNECTION_BAD) {
        resultSet->error = "can not recover connection";
        return resultSet;
      }
    }

    if(paramCount == 0) {
        res = PQexec(conn, query);
    } else {
        res = PQexecParams(conn, query, paramCount, NULL, paramValues, NULL, NULL, 0);
    }

    char* error = PQerrorMessage(conn);
    if(error[0] != '\0') {
      if(reconnect == 1 && starts_with("server closed the connection", error) == 1) {
        free(res);
        printf("Connection was closed re-trying ...\n");
        // connection will be reset at the beginning of this recurrent call
        return perform_query(conn, query, paramCount, paramValues, 0);
      }

      resultSet->error = error;
      return resultSet;
    }

    error = PQresultErrorMessage(res);
    if(error[0] != '\0') {
        resultSet->error = error;
        return resultSet;
    }

    if (PQresultStatus(res) != PGRES_TUPLES_OK) {
        return resultSet;
    }

    resultSet->res = res;

    resultSet->columnsNumber = PQnfields(res);

    resultSet->columnNames = malloc(resultSet->columnsNumber * sizeof(char*));
    resultSet->columnTypes = malloc(resultSet->columnsNumber * sizeof(int*));
    for(int col = 0; col < resultSet->columnsNumber; col++) {
        resultSet->columnNames[col] = PQfname(res, col);
        resultSet->columnTypes[col] = PQftype(res, col);
    }

    resultSet->rowsNumber = PQntuples(res);
    resultSet->rows = malloc(resultSet->rowsNumber * sizeof(char**));
    for(int row = 0; row < resultSet->rowsNumber; row++) {
      resultSet->rows[row] = malloc(resultSet->columnsNumber * sizeof(char*));
      for(int col = 0; col < resultSet->columnsNumber; col++) {
        if(PQgetisnull(res, row, col) == 1) {
            resultSet->rows[row][col] = NULL;
        } else {
            resultSet->rows[row][col] = PQgetvalue(res, row, col);
        }
      }
    }

    return resultSet;
}

void close_result_set(ResultSet* resultSet) {
    if(resultSet->res != NULL) {
      PQclear(resultSet->res);
    }
    free(resultSet);
}

void close_connection(PGconn*  conn) {
  PQfinish(conn);
}
