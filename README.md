# SQL playground 

## Description

As I am reading some important SQL books, I am extracting some core concepts and approaches and putting the relevant code snippets here.

## Contents
* GroupByMonth.mysql 
  * example query on how to calculate the % of something per month
* RelationalDivision.sql
  * from Celko's book "SQL for smarties" with my notes.
* MSSQL_RANDOMIZER.sql
  * handy code for creating random numbers
  * TBD: use seconds from system time to randomize further
* split_by_delimiter_with_trigger.sql
 * given an input string in the format 'value1;value2;value3;value4;value5;value6' we split it and parse it into separate columns
 * the code can be implemented as a trigger after INSERT on a drop table
 * the values from the temp table can then we written to a curated table
