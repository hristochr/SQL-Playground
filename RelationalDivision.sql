CREATE TABLE PilotSkills
(
	pilot CHAR(15) NOT NULL,
	plane CHAR(15) NOT NULL,
	PRIMARY KEY (pilot, plane)
);
GO

INSERT INTO PilotSkills VALUES
('Celko', 'Piper Cub'),
('Higgins', 'B-52 Bomber'),
('Higgins', 'F-14 Fighter'),
('Higgins', 'Piper Cub'),
('Jones', 'B-52 Bomber'),
('Jones', 'F-14 Fighter'),
('Smith', 'B-1 Bomber'),
('Smith', 'B-52 Bomber'),
('Smith', 'F-14 Fighter'),
('Wilson', 'B-1 Bomber'),
('Wilson', 'B-52 Bomber'),
('Wilson', 'F-14 Fighter'),
('Wilson', 'F-17 Fighter')

CREATE TABLE Hangar
(
	plane CHAR(15) NOT NULL PRIMARY KEY
);
GO

INSERT INTO Hangar VALUES
('B-1 Bomber'),
('B-52 Bomber'),
('F-14 Fighter')

/*relational division method 1 (with remainder), 2 nested queries -> give me all pilots for whom there are NO planes in the hanger that 
they can NOT fly*/
SELECT DISTINCT pilot
           FROM PilotSkills AS PS1 
      WHERE NOT EXISTS
       (SELECT *
          FROM Hangar
         WHERE NOT EXISTS
               (SELECT *
                  FROM PilotSkills AS PS2
                 WHERE (PS1.pilot = PS2.pilot)
                   AND (PS2.plane = Hangar.plane)));
/*
result set:				   
===============
'Smith'
'Wilson' 
*/
				 
/*relational division method 2 (with remainder), 2 nested queries -> give me all pilots whose skill matches the RQ in the hangar,
  then goup by pilot for those that can fly all planes*/
      SELECT PS1.pilot
        FROM PilotSkills AS PS1, Hangar AS H1
       WHERE PS1.plane = H1.plane
    GROUP BY PS1.pilot
HAVING COUNT(PS1.plane) = (SELECT COUNT(plane) FROM Hangar);

/*relational division method 3 (exact) -> give me pilots whose skills have the same number as the number of planes and they match 
  the planes in the hangar */
         SELECT PS1.pilot
           FROM PilotSkills AS PS1
LEFT OUTER JOIN Hangar AS H1
             ON PS1.plane = H1.plane
       GROUP BY PS1.pilot
  HAVING COUNT(PS1.plane) = (SELECT COUNT(plane) FROM Hangar)
  AND COUNT(H1.plane) = (SELECT COUNT(plane) FROM Hangar);

/*
result set:				   
===============
'Smith'
*/
