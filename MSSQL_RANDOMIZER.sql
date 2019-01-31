CREATE TABLE RandomNbrs2
(seq_nbr INTEGER PRIMARY KEY,
randomizer FLOAT 
DEFAULT ((CASE (CAST(RAND() + 0.5 AS INTEGER) * -1)
	      WHEN 0.0 THEN 1.0 ELSE -1.0 END)
		  * (CAST(RAND() * 100000 AS INTEGER) 10000)
		  * RAND()) NOT NULL);
      
INSERT INTO RandomNbrs2
VALUES 
(1, DEFAULT),
(2, DEFAULT),
(3, DEFAULT),
(4, DEFAULT),
(5, DEFAULT),
(6, DEFAULT),
(7, DEFAULT),
(8, DEFAULT),
(9, DEFAULT),
(10, DEFAULT);