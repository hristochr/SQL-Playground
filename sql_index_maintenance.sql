-- credit: Chad Boyd MSSQLTips.com
-- https://www.mssqltips.com/sqlservertip/2270/custom-sql-server-index-defrag-and-rebuild-procedures/

use master;
go

if exists (select * from sysobjects where name='sp_indexdefrag' and type='P')
	drop proc sp_indexdefrag;
go

create procedure dbo.sp_indexdefrag
	@maxfrag 			decimal = 0.0,		-- Maximum fragmetation to allow an index to have without defraging
	@processresults		bit = 0,			-- Set to 1 to perform the actual defrag/rebuild on any resulting tables. 
											-- If 0, only the results of the scan will display
	@endtime			datetime = null,	-- If set, the operation will stop as soon as the specified endtime is reached
	@opts				int = 0,			-- Options that define execution.
											-- 1 bit =	If set, a full rebuild on each index instead of just a defrag.
											-- 2 bit =	If set, perform a stats update on the affected tables as well as the defrag
											-- 4 bit =	If set, dm_db_index_physical_stats results are output
											-- 8 bit =	If set, dm_db_index_physical_stats results are saved to the fully qualified location specified in
											--			the @contigouttable parameter (i.e. server.db.owner.tablename)
											-- 16 bit = If set, and if the 1 bit is set, rebuild in performed online
											-- 32 bit = If set, all execution of index defragging is disabled and statements are simply printed...
											-- 64 bit = If set, and 8 bit is set, the insert into the contigout table is just that, a straight insert, instead of a
											--			drop of the existing table if it exists then a select...into operation (what happens if the 64 bit isn't set)
											-- 128 bit = If set, and the 1 bit is set (i.e. perform a full rebuild), and the 16 bit is set (online operation), and 
											--			an index is partitioned, we will simply rebuild the given partition(s) offline - by default, we throw an 
											--			error (not supported)
	@contigouttable		varchar(200) = 'dbo.ztbl_fraginfo'	-- Fully qualified (i.e. server.db.owner.tablename) table to store the contig output to, be sure
											-- to set the 8 bit in @opts as well, or this is ignored.  If the table exists, it will be 
											-- dropped and recreated, so be sure to specify the name of a table you don't want destroyed

as

set nocount on;
set transaction isolation level read uncommitted;

/*

exec zSql2005_Maint.dbo.sp_indexdefrag 1.0, 1, default,49, null

*/

-- Declare variables
declare		@tablename 		varchar(128),
			@execstr   		nvarchar(4000),
			@ispartitioned	tinyint,
			@objschema  	varchar(250),
			@frag      		decimal,
			@indexname		varchar(255),
			@partition		int,
			@itype			nvarchar(250),
			@clist			nvarchar(3500)

-- Set defaults
select	@maxfrag = coalesce(@maxfrag, 0.0),
		@clist = '',
		@processresults = coalesce(@processresults, 0), 
		@endtime = 	case
						when @endtime is null	then dateadd(hh, 12, getdate())	-- 12 hours max, even if not told so
						when datepart(yyyy, @endtime) = '1900' then dateadd(hh, 12, getdate())
						when datediff(hh, getdate(), @endtime) > 12 then dateadd(hh, 12, getdate())	-- again, 12 hours max
						when datediff(mi, getdate(), @endtime) < 0 then getdate() -- No negative times
						else @endtime
					end;

if @maxfrag > 100
	select @maxfrag = 100.0;

-- Cleanup if needed
if object_id('tempdb..##fraglist') > 0
	drop table ##fraglist;

print 'Getting contig data'

-- Get the fragmentation information for all indexes of user tables...
set @execstr = '
select	o.name as objectName, o.type as objectType, o.object_id as objectId, schema_name(o.schema_id) as objectSchema,
		i.index_id as indexId, i.type_desc as indexType, i.name as indexName, 
		case when p.partObjId > 0 then 1 else 0 end as isPartitioned,
		s.partition_number as partitionNumber, s.alloc_unit_type_desc as allocUnitType,
		s.index_depth as indexDepth, s.index_level as indexLevel, s.avg_fragmentation_in_percent as avgFragPercent,
		s.fragment_count as fragCount, s.avg_fragment_size_in_pages as avgFragSizePages, s.page_count as pageCount,
		s.avg_page_space_used_in_percent as avgPageSpaceUsedPercent, s.record_count as recCount, s.min_record_size_in_bytes as minRecSizeBytes,
		s.max_record_size_in_bytes as maxRecSizeBytes, s.avg_record_size_in_bytes as avgRecSizeBytes
into	##fraglist
from	' + db_name() + '.sys.dm_db_index_physical_stats(db_id(), default, default, default, ''SAMPLED'') s
join	' + db_name() + '.sys.indexes i with(nolock)
on		s.index_id = i.index_id
and		s.object_id = i.object_id
join	' + db_name() + '.sys.objects o with(nolock)
on		i.object_id = o.object_id
left join (select object_id as partObjId, index_id partIndId from ' + db_name() + '.sys.partitions where partition_number > 1 group by object_id, index_id) p
on		s.object_id = p.partObjId
and		s.index_id = p.partIndId
where	o.is_ms_shipped = 0
and		s.index_type_desc <> ''HEAP''';

exec (@execstr);

-- If we are flagged to process the results, do the defrag/rebuild on each of the indexes as needed
if (@processresults > 0) begin
	print 'Processing defrag/rebuilds';

	-- Declare cursor for list of indexes to be defragged, ordered by most fraged
	declare indexes cursor local fast_forward for
		select	objectName, isPartitioned, avgFragPercent, indexName, partitionNumber, objectSchema, indexType
		from	##fraglist
		where	((avgFragPercent >= @maxfrag)
				or ((100.0-avgPageSpaceUsedPercent) >= @maxfrag))
		and		indexDepth > 0
		and		pageCount > 2500
		order by avgFragPercent desc;

	-- Open the cursor
	open indexes;
		
	-- Index loop
	while 1 = 1 begin
		-- loop through the indexes
		fetch next from indexes into @tablename, @ispartitioned, @frag, @indexname, @partition, @objschema, @itype;

		if @@fetch_status <> 0
			break;

		-- Check to see if we should be doing a full rebuild or just a defragmentation
		if (@opts & 1 = 1) begin

			if @ispartitioned > 0 begin
				-- If we are set to perform an online rebuild and the object is partitioned, we'll throw an error unless the user said to ignore (128 bit)
				if @opts & 144 = 16 begin
					raiserror('Index [%s].[%s].[%s] is partitioned and an online rebuild was requested - online rebuilds of a partition are not supported. Try again specifying either an offline rebuild or to ignore online partition errors (set option 128).', 16, 1, @objschema, @tablename, @indexname);
					set @execstr = '';
				end else begin
					set @execstr = 'alter index ' + quotename(@indexname) + ' on ' + quotename(db_name()) + '.' + quotename(@objschema) + '.' + quotename(@tablename) + 
									' rebuild partition = ' + cast(@partition as varchar(20)) + ' with(sort_in_tempdb = on);';
				end
			
			end else begin
				set @execstr = 'alter index ' + quotename(@indexname) + ' on ' + quotename(db_name()) + '.' + quotename(@objschema) + '.' + quotename(@tablename) + 
								' rebuild with(sort_in_tempdb = on' + 
								case when @opts & 16 = 16 then ', online = on' else '' end + ');';
			end
		
		-- Not performing full rebuild...
		end else begin

			if @ispartitioned > 0
				set @execstr = 'alter index ' + quotename(@indexname) + ' on ' + quotename(db_name()) + '.' + quotename(@objschema) + '.' + quotename(@tablename) + 
									' reorganize partition = ' + cast(@partition as varchar(20)) + ';';
			else
				set @execstr = 'alter index ' + quotename(@indexname) + ' on ' + quotename(db_name()) + '.' + quotename(@objschema) + '.' + quotename(@tablename) + 
									' reorganize;';

		end

		-- Execute the defrag/rebuild
		-- Execute or print...
		if len(@execstr) > 0 begin
		
			if @opts & 32 = 32 begin
				print @execstr;
			end else begin
				-- Print an update line
				print 'Executing defrag/reindex for table/view ' + quotename(@tablename) + ', index ' + quotename(@indexname) + ' - fragmentation currently ' + ltrim(rtrim(convert(varchar, @frag))) + '%';
				exec (@execstr);
			end

		end
		
		-- Ensure we haven't passed our time threshold
		if datediff(ms, getdate(), @endtime) < 0 begin
			print 'HIT TIME THRESHOLD OF ' + quotename(cast(@endtime as varchar)) + ' - EXITING NOW';
			break;
		end

		-- Check to see if we are flagged to update statistics on the affected tables in addition to the defrag/rebuild...
		-- Don't bother updating stats if we performed a full rebuild, that updates stats for us...
		if (@opts & 3 = 2) and (upper(@itype) <> 'XML')  begin
			-- Update stats on the table and index in question...
			set @execstr = 'update statistics ' + quotename(@objschema) + '.' + quotename(@tablename) + ' (' + quotename(@indexname) + ');';

			-- Execute the stats update
			-- Execute or print...
			if @opts & 32 = 32 begin
				print @execstr;
			end else begin
				-- Print an update
				print 'Updating stats for table ' + quotename(@tablename) + ', index ' + quotename(@indexname);
				exec (@execstr);
			end

		end	-- if (@opts & 3 = 2)

		-- Ensure we haven't passed our time threshold
		if datediff(ms, getdate(), @endtime) < 0 begin
			print 'HIT TIME THRESHOLD OF ' + quotename(cast(@endtime as varchar)) + ' - EXITING NOW';
			break;
		end

	end	-- while 1 = 1

	-- Close and deallocate the cursor
	close indexes;
	deallocate indexes;
end	-- if @processresults = 1

-- If we are supposed to output the contig info somewhere, do so
if (@opts & 8 = 8) and (len(@contigouttable) > 0) begin

	if @opts & 64 = 0 begin
		select @execstr = 'if object_id(''' + @contigouttable + ''') > 0 drop table ' + @contigouttable + ' ' +
							' select * into ' + @contigouttable + ' from ##fraglist';
	end else begin
		select @clist = @clist + case when len(@clist) > 0 then ',' else '' end + name from tempdb.sys.columns where object_id = object_id('tempdb..##fraglist');
		select @execstr = 'insert ' + @contigouttable + ' (' + @clist + ') select * from ##fraglist';
	end

	exec(@execstr);
end	-- if (@opts & 8 = 8) and (len(@contigouttable) > 0)

-- Show the results of the initial frag list, if asked to do so
if @opts & 4 = 4
	select	*
	from	##fraglist
	where	avgFragPercent >= @maxfrag
	and		indexDepth > 0
	order by avgFragPercent desc;

if cursor_status('local', 'indexes') >= 0 begin  -- Check to ensure the indexes cursor is closed
	close indexes;
	deallocate indexes;
end

drop table ##fraglist;

print 'Processing complete.';
go
