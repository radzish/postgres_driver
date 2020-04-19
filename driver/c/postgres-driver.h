typedef struct _ResultSet {
  char* error;
  int columnsNumber;
  int rowsNumber;
  char** columnNames;
  int* columnTypes;
  char*** rows;
  PGresult* res;
} ResultSet;

typedef struct _SendQueryResult {
  char* error;
} SendQueryResult;

PGconn* open_connection(char* connection_string);
SendQueryResult* send_query(PGconn* conn, char* query, int paramCount, const char * const* paramValues, int reconnect);
ResultSet* get_result(PGconn*  conn);
void close_connection(PGconn*  conn);
void close_result_set(ResultSet*  rs);

ResultSet* test();
