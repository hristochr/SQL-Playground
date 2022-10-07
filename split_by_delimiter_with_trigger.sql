DECLARE @tagvalue VARCHAR(200) = 'P10;242141;2;60;59;52'+';' 
--'P21;MT;47;8672.906389;;'
--'P10;242141;2;60;59;52'+';' 
--'P19;255041;1;595.0605;;'
--'P16;211041;3;22.39475;;'
DECLARE @t DATETIME = '2022-10-07'

DECLARE @temp_table TABLE (
                tt_id INT
                ,tt_p1 VARCHAR(3)
                ,tt_p2 VARCHAR(8)
                ,tt_p3 TINYINT
                ,tt_p4 VARCHAR(20)
                ,tt_p5 VARCHAR(20)
                ,tt_p6 VARCHAR(20)
                ,tt_timestamp DATETIME
    )
INSERT INTO @temp_table (tt_id,tt_timestamp) VALUES ('59747',@t)

DECLARE @current_val VARCHAR(50)
        ,@startingPosition SMALLINT = 0
        ,@stringlength SMALLINT = 0
        ,@counter TINYINT = 0;

WHILE CHARINDEX(';', @tagvalue, @startingPosition) > 0
    BEGIN      
        SET @stringlength = CHARINDEX(';', @tagvalue, @startingPosition)
        SET @current_val = SUBSTRING(@tagvalue, @startingPosition, @stringlength-@startingPosition)      
        SET @startingPosition = CHARINDEX(';', @tagvalue, @stringlength)+1;      
         
        IF @counter = 0 
            BEGIN
                UPDATE @temp_table
                SET tt_p1 = @current_val
                WHERE tt_timestamp = @t
            END
        IF @counter = 1                      
            BEGIN
                UPDATE @temp_table
                SET tt_p2 = @current_val
                WHERE tt_timestamp = @t
            END
        IF @counter = 2 
            BEGIN                   
                UPDATE @temp_table
                SET tt_p3 = @current_val
                WHERE tt_timestamp = @t
            END
        IF @counter = 3                      
            BEGIN
                UPDATE @temp_table
                SET tt_p4 = @current_val
                WHERE tt_timestamp = @t            
            END
        IF @counter = 4 
            BEGIN                     
                UPDATE @temp_table
                SET tt_p5 = @current_val
                WHERE tt_timestamp = @t            
            END
        IF @counter = 5 
            BEGIN                    
                UPDATE @temp_table
                SET tt_p6 = @current_val
                WHERE tt_timestamp = @t            
            END;
        
        SET @counter = @counter + 1         
        
    END             

SELECT * FROM @temp_table
