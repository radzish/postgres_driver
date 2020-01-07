#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libpq-fe.h>
#include "postgres-driver.h"

PGconn* open_connection(char* connection_string) {
    PGconn* conn = PQconnectdb(connection_string);

    if (PQstatus(conn) == CONNECTION_BAD) {
        printf("Connection to database failed: %s\n", PQerrorMessage(conn));
        PQfinish(conn);
        return NULL;
    }

    return conn;
}

ResultSet* perform_query(PGconn* conn, char* query, int paramCount, const char * const* paramValues) {

    PGresult *res;

    if(paramCount == 0) {
        res = PQexec(conn, query);
    } else {
        res = PQexecParams(conn, query, paramCount, NULL, paramValues, NULL, NULL, 0);
    }


    ResultSet* resultSet = (ResultSet*)malloc(sizeof(ResultSet));
    resultSet->error = NULL;
    resultSet->res = res;
    resultSet->columnsNumber = 0;
    resultSet->columnNames = NULL;
    resultSet->rowsNumber = 0;
    resultSet->rows = NULL;

    char* error = PQresultErrorMessage(res);
    if(error[0] != '\0') {
        resultSet->error = error;
        return resultSet;
    }

    if (PQresultStatus(res) != PGRES_TUPLES_OK) {
        return resultSet;
    }

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
    PQclear(resultSet->res);
    free(resultSet);
}

void close_connection(PGconn*  conn) {
  PQfinish(conn);
}
