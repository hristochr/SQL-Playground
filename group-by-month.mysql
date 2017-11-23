/*mysql syntax*/
vim: syntax=mysql

  SELECT col1,
         col2,
         col3,
	   	CASE MONTH(col4) /*datetime column*/
			    WHEN 1 THEN "January" 
			    WHEN 2 THEN "February" 
			    WHEN 3 THEN "March" 
			    WHEN 4 THEN "April" 
			    WHEN 5 THEN "May" 
			    WHEN 6 THEN "June" 
			    WHEN 7 THEN "July" 
			    WHEN 8 THEN "August" 
			    WHEN 9 THEN "September" 
			    WHEN 10 THEN "October" 
			    WHEN 11 THEN "November" 
			    WHEN 12 THEN "December" 
		   END AS 'Month',
	   	ROUND(COUNT(*)/893*100,2) AS 'Percentage' /*893 - example total count of records*/
    FROM table name
GROUP BY MONTH(col4)  /*datetime column*/
ORDER BY Percentage DESC
