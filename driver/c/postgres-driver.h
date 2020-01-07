typedef struct _ResultSet {
  char* error;
  int columnsNumber;
  int rowsNumber;
  char** columnNames;
  int* columnTypes;
  char*** rows;
  PGresult* res;
} ResultSet;

PGconn* open_connection(char* connection_string);
ResultSet* perform_query(PGconn* conn, char* query, int paramCount, const char * const* paramValues);
void close_connection(PGconn*  conn);
void close_result_set(ResultSet*  rs);

ResultSet* test();
