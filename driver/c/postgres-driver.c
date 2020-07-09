#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libpq-fe.h>
#include <stdarg.h>
#include "postgres-driver.h"

int starts_with(const char *pre, const char *str) {
    size_t lenpre = strlen(pre),
           lenstr = strlen(str);
    return lenstr < lenpre ? 0 : (memcmp(pre, str, lenpre) == 0 ? 1 : 0);
}

ResultSet* test() {
//  PGconn* conn = open_connection("dbname=postgres_dart_test user=postgres_dart_test password=postgres_dart_test host=localhost");
//
//  if(PQsetnonblocking(conn, 1) == -1) {
//      printf("Impossible to set nonblocking: %s\n", PQerrorMessage(conn));
//    return NULL;
//  }
//
//  PQsendQuery(conn, "select invalid query");
//
//  do {
//    PQconsumeInput(conn);
//  } while(PQisBusy(conn));
//
//  PGresult *res = PQgetResult(conn);
//
//  printf("error 0: %s", PQerrorMessage(conn));
//
//  do {
//    PQconsumeInput(conn);
//  } while(PQisBusy(conn));
//
//  printf("error 0: %s", PQerrorMessage(conn));
//
//  PQsendQuery(conn, "select 1");
//
//  do {
//    PQconsumeInput(conn);
//  } while(PQisBusy(conn));
//
//  PQgetResult(conn);
//
//  printf("error 1: %s", PQerrorMessage(conn));
//
//  close_connection(conn);
}

int error_changed(char* oldError, char* newError) {
  return strlen(oldError) != strlen(newError) ? 1 : 0;
}

PGconn* open_connection(char* connection_string) {
    PGconn* conn = PQconnectdb(connection_string);

    if(PQsetnonblocking(conn, 1) == -1) {
        printf("Impossible to set nonblocking: %s\n", PQerrorMessage(conn));
      return NULL;
    }

    if (PQstatus(conn) == CONNECTION_BAD) {
        printf("Connection to database failed: %s\n", PQerrorMessage(conn));
        PQfinish(conn);
        return NULL;
    }

    return conn;
}

SendQueryResult* send_query(PGconn* conn, char* query, int paramCount, const char * const* paramValues, int reconnect) {
  SendQueryResult* sendQueryResult = (SendQueryResult*)malloc(sizeof(SendQueryResult));
  sendQueryResult->error = NULL;

  if (PQstatus(conn) == CONNECTION_BAD) {
    printf("Connection is bad, trying to recover ...\n");
    PQreset(conn);
    if (PQstatus(conn) == CONNECTION_BAD) {
      sendQueryResult->error = "can not recover connection";
      return sendQueryResult;
    }
  }

  int res;

  if(paramCount == 0) {
      res = PQsendQuery(conn, query);
  } else {
      res = PQsendQueryParams(conn, query, paramCount, NULL, paramValues, NULL, NULL, 0);
  }

  if(res == 0 ) {
    char* error = PQerrorMessage(conn);
      if(error[0] != '\0') {
        if(reconnect == 1 && starts_with("server closed the connection", error) == 1) {
          free(sendQueryResult);
          printf("Connection was closed re-trying ...\n");
          // connection will be reset at the beginning of this recurrent call
          return send_query(conn, query, paramCount, paramValues, 0);
        }

        sendQueryResult->error = error;
        return sendQueryResult;
      }
  }

  return sendQueryResult;
}

ResultSet* get_result(PGconn*  conn) {

//  char* error1 = PQerrorMessage(conn);
//  if(error1[0] != '\0') {
//    if(starts_with("FATAL:  terminating connection", error) == 1) {
//      printf("Connection was closed re-trying ...\n");
//      PQreset(conn);
//      // connection will be reset at the beginning of this recurrent call
//      return send_query(conn, query, paramCount, paramValues, 0);
//    }
//
//    sendQueryResult->error = error1;
//    return sendQueryResult;
//  }

  ResultSet* resultSet = (ResultSet*)malloc(sizeof(ResultSet));
  resultSet->res = NULL;
  resultSet->error = NULL;
  resultSet->columnsNumber = 0;
  resultSet->columnNames = NULL;
  resultSet->rowsNumber = 0;
  resultSet->rows = NULL;

  int consumeInputResult = PQconsumeInput(conn);

  if(!consumeInputResult) {
    char* error = PQerrorMessage(conn);
      if(error[0] != '\0') {
        resultSet->error = error;
        return resultSet;
      }
  }

  int isBusy = PQisBusy(conn);
  if(isBusy) {
    // no result from server yet, query is executing, so we are just returning with empty result set
    // which should be properly handled by client to loop waiting for result
    return resultSet;
  }

  PGresult *res = PQgetResult(conn);

  if(res == NULL) {
    return NULL;
  }

  printf("GET RESULT 0\n");fflush(stdout);

  char* error = PQresultErrorMessage(res);
  if(error[0] != '\0') {

    while(PQconsumeInput(conn) && PQisBusy(conn));

    printf("GET RESULT 2\n");fflush(stdout);

    PQclear(resultSet->res);
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
