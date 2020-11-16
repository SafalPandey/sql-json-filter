DROP function IF EXISTS apply_filter;


/*
 * Function to filter any table based on JSON params in SQL
 */
CREATE function apply_filter (
  tablename VARCHAR(255),
  params json,
  conjunction VARCHAR(3) = 'AND'
)
RETURNS SETOF RECORD
LANGUAGE PLPGSQL
AS
$BODY$
DECLARE
  invalid_keys text = '';
  sql_query text;
BEGIN

  DROP TABLE columns;
  CREATE TEMP TABLE columns (
    name VARCHAR(255)
  );

  --
  -- Step 1: Get the column list
  --
  INSERT INTO columns
  SELECT
    column_name
  FROM INFORMATION_SCHEMA.columns
  WHERE TABLE_NAME = tablename;

  DROP TABLE param_table;
  CREATE TEMP TABLE param_table (
    filter_key VARCHAR(255),
    filter_value text
  );

  --
  -- Step 2: Parse the supplied JSON parameter
  --
  INSERT INTO param_table (filter_key, filter_value)
  SELECT
    key AS filter_key,
    value AS filter_value
  FROM json_each_text(params);

  invalid_keys := (
    SELECT
      STRING_AGG(name, ', ')
    FROM (
      SELECT filter_key AS name FROM param_table
      EXCEPT
      SELECT name FROM columns
    ) x
  );

  --
  -- Step 3: Error handling for invalid columns in JSON
  --
  IF (invalid_keys <> '') THEN
    RAISE EXCEPTION 'The source table does not have some filter key(s) that exist in the param: %', invalid_keys;
  END IF;

  --
  -- Step 4: Generate dynamic SQL statement
  --
  sql_query :=
  'SELECT ' || (
    --
    -- Append comma separated string of column names in tablename
    --
    SELECT STRING_AGG(name, ',') FROM columns
  ) || ' FROM ' || tablename || ' s
  WHERE ' || (
    --
    -- Generate and add the where clause based on
    -- @param and @conjunction
    --
    SELECT
      STRING_AGG(
        ' s.' || filter_key || ' = ''' || filter_value || ''' ',
        conjunction
      )
    FROM param_table
  );

  -- Show the generated SQL query
   RAISE NOTICE '%', sql_query;

  -- Execute the generated SQL query to get the filtered result set
  RETURN QUERY EXECUTE sql_query;
END
$BODY$
