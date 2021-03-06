USE CAD_PHAR_V3
GO
ALTER PROCEDURE [dbo].[PHAR_FA_REJ_CHART] @pWeek NVARCHAR(12) = NULL
	,@pFieldName NVARCHAR(50) = NULL
	,@pGroupField NVARCHAR(50) = NULL
AS
BEGIN
	DECLARE @Total DECIMAL(12, 2)
		,@StartDate DATETIME
		,@EndDate DATETIME
		,@StartDay TINYINT
		,@WhereCondition NVARCHAR(500)
		,@SQL NVARCHAR(4000)

	SELECT @StartDay = CODE
	FROM dbo.SUP_SUPPORT_CODE
	WHERE CODE_TYPE = 'FA_FIRST_DAY_OF_WEEK'

	SET DATEFIRST @StartDay

	------------------------------------------------------------------------------
	--Dev only                                                                  --
	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @pWeek = '2015-05-25' --
			------------------------------------------------------------------------------

	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @StartDate = DATEADD(dd, - 7, DATEADD(dd, 1 - DATEPART(dw, GETDATE()), CONVERT(DATETIME, FLOOR(CONVERT(DECIMAL(16, 4), GETDATE())))))
	ELSE
		SET @StartDate = CAST(@pWeek AS DATETIME)

	SET @EndDate = DATEADD(dd, 6, @StartDate)

	IF @pFieldName IS NULL
		OR @pFieldName = ''
		SET @pFieldName = 'PROTECTED_CLASS_IMPROPER_COUNT'

	IF @pGroupField IS NULL
		OR @pGroupField = ''
		SET @pGroupField = 'EDITES'
	SET @WhereCondition = 'WHERE IGNORE = 0 AND CLAIM_ACCEPTED = 0 '

	IF @pFieldName = 'PROTECTED_CLASS_PROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 0 AND c2.CODE = ''Protected Class'' '

	IF @pFieldName = 'PROTECTED_CLASS_IMPROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 1 AND c2.CODE = ''Protected Class'' '

	IF @pFieldName = 'PROTECTED_CLASS_OPEN_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''Protected Class'' AND c1.CODE = ''1'' '

	IF @pFieldName = 'PROTECTED_CLASS_PENDING_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''Protected Class'' AND c1.CODE = ''2'' '

	IF @pFieldName = 'PROTECTED_CLASS_RESOLVED_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''Protected Class'' AND c1.CODE = ''3'' '

	IF @pFieldName = 'PRIOR_AUTH_PROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 0 AND c2.CODE = ''PA'' '

	IF @pFieldName = 'PRIOR_AUTH_IMPROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 1 AND c2.CODE = ''PA'' '

	IF @pFieldName = 'PRIOR_AUTH_OPEN_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''PA'' AND c1.CODE = ''1'' '

	IF @pFieldName = 'PRIOR_AUTH_PENDING_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''PA'' AND c1.CODE = ''2'' '

	IF @pFieldName = 'PRIOR_AUTH_RESOLVED_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''PA'' AND c1.CODE = ''3'' '

	IF @pFieldName = 'STEP_THERAPY_PROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 0 AND c2.CODE = ''ST'' '

	IF @pFieldName = 'STEP_THERAPY_IMPROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 1 AND c2.CODE = ''ST'' '

	IF @pFieldName = 'STEP_THERAPY_OPEN_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''ST'' AND c1.CODE = ''1'' '

	IF @pFieldName = 'STEP_THERAPY_PENDING_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''ST'' AND c1.CODE = ''2'' '

	IF @pFieldName = 'STEP_THERAPY_RESOLVED_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''ST'' AND c1.CODE = ''3'' '

	IF @pFieldName = 'QUANTITY_LIMIT_PROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 0 AND c2.CODE = ''QL'' '

	IF @pFieldName = 'QUANTITY_LIMIT_IMPROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 1 AND c2.CODE = ''QL'' '

	IF @pFieldName = 'QUANTITY_LIMIT_OPEN_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''QL'' AND c1.CODE = ''1'' '

	IF @pFieldName = 'QUANTITY_LIMIT_PENDING_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''QL'' AND c1.CODE = ''2'' '

	IF @pFieldName = 'QUANTITY_LIMIT_RESOLVED_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''QL'' AND c1.CODE = ''3'' '

	IF @pFieldName = 'NONFORMULARY_PROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 0 AND c2.CODE = ''Non-FORMULARY'' '

	IF @pFieldName = 'NONFORMULARY_IMPROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 1 AND c2.CODE = ''Non-FORMULARY'' '

	IF @pFieldName = 'NONFORMULARY_OPEN_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''Non-FORMULARY'' AND c1.CODE = ''1'' '

	IF @pFieldName = 'NONFORMULARY_PENDING_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''Non-FORMULARY'' AND c1.CODE = ''2'' '

	IF @pFieldName = 'NONFORMULARY_RESOLVED_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''Non-FORMULARY'' AND c1.CODE = ''3'' '

	IF @pFieldName = 'REFILL_TOO_SOON_PROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 0 AND c2.CODE = ''RFTS'' '

	IF @pFieldName = 'REFILL_TOO_SOON_IMPROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 1 AND c2.CODE = ''RFTS'' '

	IF @pFieldName = 'REFILL_TOO_SOON_OPEN_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''RFTS'' AND c1.CODE = ''1'' '

	IF @pFieldName = 'REFILL_TOO_SOON_PENDING_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''RFTS'' AND c1.CODE = ''2'' '

	IF @pFieldName = 'REFILL_TOO_SOON_RESOLVED_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''RFTS'' AND c1.CODE = ''3'' '

	IF @pFieldName = 'COB_PROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 0 AND c2.CODE = ''COB'' '

	IF @pFieldName = 'COB_IMPROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 1 AND c2.CODE = ''COB'' '

	IF @pFieldName = 'COB_OPEN_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''COB'' AND c1.CODE = ''1'' '

	IF @pFieldName = 'COB_PENDING_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''COB'' AND c1.CODE = ''2'' '

	IF @pFieldName = 'COB_RESOLVED_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''COB'' AND c1.CODE = ''3'' '

	IF @pFieldName = 'MEMBER_ID_PROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 0 AND c2.CODE = ''Member ID'' '

	IF @pFieldName = 'MEMBER_ID_IMPROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 1 AND c2.CODE = ''Member ID'' '

	IF @pFieldName = 'MEMBER_ID_OPEN_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''Member ID'' AND c1.CODE = ''1'' '

	IF @pFieldName = 'MEMBER_ID_PENDING_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''Member ID'' AND c1.CODE = ''2'' '

	IF @pFieldName = 'MEMBER_ID_RESOLVED_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''Member ID'' AND c1.CODE = ''3'' '

	IF @pFieldName = 'MISC_PROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 0 AND c2.CODE = ''MISC'' '

	IF @pFieldName = 'MISC_IMPROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 1 AND c2.CODE = ''MISC'' '

	IF @pFieldName = 'MISC_OPEN_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''MISC'' AND c1.CODE = ''1'' '

	IF @pFieldName = 'MISC_PENDING_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''MISC'' AND c1.CODE = ''2'' '

	IF @pFieldName = 'MISC_RESOLVED_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''MISC''  AND c1.CODE = ''3'''

	IF @pFieldName = 'PHARMACY_PROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 0 AND c2.CODE = ''PHARMACY'' '

	IF @pFieldName = 'PHARMACY_IMPROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 1 AND c2.CODE = ''PHARMACY'' '

	IF @pFieldName = 'PHARMACY_OPEN_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''PHARMACY'' AND c1.CODE = ''1'' '

	IF @pFieldName = 'PHARMACY_PENDING_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''PHARMACY'' AND c1.CODE = ''2'' '

	IF @pFieldName = 'PHARMACY_RESOLVED_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''PHARMACY'' AND c1.CODE = ''3'' '

	IF @pFieldName = 'PRESCRIBER_PROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 0 AND c2.CODE = ''PRESCRIBER'' '

	IF @pFieldName = 'PRESCRIBER_IMPROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 1 AND c2.CODE = ''PRESCRIBER'' '

	IF @pFieldName = 'PRESCRIBER_OPEN_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''PRESCRIBER'' AND c1.CODE = ''1'' '

	IF @pFieldName = 'PRESCRIBER_PENDING_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''PRESCRIBER'' AND c1.CODE = ''2'' '

	IF @pFieldName = 'PRESCRIBER_RESOLVED_COUNT '
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''PRESCRIBER'' AND c1.CODE = ''3'' '

	IF @pFieldName = 'RX_COST_PROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 0 AND c2.CODE = ''Rx COST'' '

	IF @pFieldName = 'RX_COST_IMPROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 1 AND c2.CODE = ''Rx COST'' '

	IF @pFieldName = 'RX_COST_OPEN_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''Rx COST'' AND c1.CODE = ''1'' '

	IF @pFieldName = 'RX_COST_PENDING_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''Rx COST'' AND c1.CODE = ''2'' '

	IF @pFieldName = 'RX_COST_RESOLVED_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''Rx COST'' AND c1.CODE = ''3'' '

	IF @pFieldName = 'RX_DURATION_PROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 0 AND c2.CODE = ''Rx DURATION'' '

	IF @pFieldName = 'RX_DURATION_IMPROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 1 AND c2.CODE = ''Rx DURATION'' '

	IF @pFieldName = 'RX_DURATION_OPEN_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''Rx DURATION'' AND c1.CODE = ''1'' '

	IF @pFieldName = 'RX_DURATION_PENDING_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''Rx DURATION'' AND c1.CODE = ''2'' '

	IF @pFieldName = 'RX_DURATION_RESOLVED_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE = ''Rx DURATION'' AND c1.CODE = ''3'' '
	SET @WhereCondition = @WhereCondition + 'AND  v.REJECTION_DATE BETWEEN ''' + CONVERT(VARCHAR(12), @StartDate, 101) + ''' AND ''' + CONVERT(VARCHAR(12), @EndDate, 101) + ''' '

	IF @pGroupField = 'EDITES'
	BEGIN
		SET @SQL = N'SELECT @Total = ISNULL(COUNT(*),0)
		FROM dbo.RX_CLAIMS_FA_REJ v
		JOIN dbo.SUP_SUPPORT_CODE c1 ON c1.CODE = v.STATUS AND c1.CODE_TYPE = ''FA_REJ_STATUS''
		--JOIN dbo.SUP_SUPPORT_CODE c2 ON c2.CODE = v.CADRE_CODE AND c2.CODE_TYPE = ''FA_REJ''
        JOIN dbo.PHAR_FA_REJECTION_CODE c2 ON c2.CODE_DESC = v.CADRE_CODE 
		'
		SET @SQL = @SQL + @WhereCondition

		EXEC sp_executesql @Query = @SQL
			,@Params = N'@Total DECIMAL(12,2) OUTPUT '
			,@Total = @Total OUTPUT

		SET @SQL = N'SELECT
			c2.CODE AS GROUP_TYPE
			,COUNT(*) AS AMOUNT
			,' + CAST(@Total AS VARCHAR(12)) + ' AS TOTAL
			,ISNULL(COUNT(*) / NULLIF(' + CAST(@Total AS VARCHAR(12)) + ',0),0) AS PERCENTAGE
		FROM dbo.RX_CLAIMS_FA_REJ v
		JOIN dbo.SUP_SUPPORT_CODE c1 ON c1.CODE = v.STATUS AND c1.CODE_TYPE = ''FA_REJ_STATUS''
		--JOIN dbo.SUP_SUPPORT_CODE c2 ON c2.CODE = v.CADRE_CODE AND c2.CODE_TYPE = ''FA_REJ''
        JOIN dbo.PHAR_FA_REJECTION_CODE c2 ON c2.CODE_DESC = v.CADRE_CODE 
		'
		SET @SQL = @SQL + @WhereCondition
		SET @SQL = @SQL + N'
		GROUP BY c2.CODE'

		PRINT @SQL

		EXEC sp_executesql @SQL
	END

	IF @pGroupField = 'TREND'
	BEGIN
		SET @SQL = N'SELECT @Total = ISNULL(COUNT(*),0)
		FROM dbo.RX_CLAIMS_FA_REJ v
		JOIN dbo.SUP_SUPPORT_CODE c1 ON c1.CODE = v.STATUS AND c1.CODE_TYPE = ''FA_REJ_STATUS''
		--JOIN dbo.SUP_SUPPORT_CODE c2 ON c2.CODE = v.CADRE_CODE AND c2.CODE_TYPE = ''FA_REJ''
        JOIN dbo.PHAR_FA_REJECTION_CODE c2 ON c2.CODE_DESC = v.CADRE_CODE 
		'
		SET @SQL = @SQL + @WhereCondition

		EXEC sp_executesql @Query = @SQL
			,@Params = N'@Total DECIMAL(12,2) OUTPUT '
			,@Total = @Total OUTPUT

		SET @SQL = N'
		SELECT 
			''' + CONVERT(VARCHAR(10), @StartDate, 101) + ' - ' + CONVERT(VARCHAR(10), @EndDate, 101) + ''' AS YEAR
			,CASE WHEN WeekNumber = 1 THEN ''Mon''
					WHEN WeekNumber = 2 THEN ''Tue''
					WHEN WeekNumber = 3 THEN ''Wed''
					WHEN WeekNumber = 4 THEN ''Thu''
					WHEN WeekNumber = 5 THEN ''Fri''
					WHEN WeekNumber = 6 THEN ''Sat''
					WHEN WeekNumber = 7 THEN ''Sun''
					END AS NUM_MONTH
			,AMOUNT
		FROM 
		(
			SELECT 
				DATEPART(dw,REJECTION_DATE) AS WeekNumber
				,ISNULL(COUNT(*),0) AS AMOUNT
            FROM dbo.RX_CLAIMS_FA_REJ v
			JOIN dbo.SUP_SUPPORT_CODE c1 ON c1.CODE = v.STATUS AND c1.CODE_TYPE = ''FA_REJ_STATUS''
			--JOIN dbo.SUP_SUPPORT_CODE c2 ON c2.CODE = v.CADRE_CODE AND c2.CODE_TYPE = ''FA_REJ''
            JOIN dbo.PHAR_FA_REJECTION_CODE c2 ON c2.CODE_DESC = v.CADRE_CODE 
			'
		SET @SQL = @SQL + @WhereCondition
		SET @SQL = @SQL + N'
			GROUP BY DATEPART(dw,REJECTION_DATE)
		) d
		ORDER BY WeekNumber
		'

		PRINT @SQL

		EXEC sp_executesql @SQL
	END

	IF @pGroupField = 'TRANSITION'
	BEGIN
		SET @SQL = N'SELECT @Total = ISNULL(COUNT(*),0)
		FROM dbo.RX_CLAIMS_FA_REJ v
		JOIN dbo.SUP_SUPPORT_CODE c1 ON c1.CODE = v.STATUS AND c1.CODE_TYPE = ''FA_REJ_STATUS''
		--JOIN dbo.SUP_SUPPORT_CODE c2 ON c2.CODE = v.CADRE_CODE AND c2.CODE_TYPE = ''FA_REJ''
        JOIN dbo.PHAR_FA_REJECTION_CODE c2 ON c2.CODE_DESC = v.CADRE_CODE 
		'
		SET @SQL = @SQL + @WhereCondition

		EXEC sp_executesql @Query = @SQL
			,@Params = N'@Total DECIMAL(12,2) OUTPUT '
			,@Total = @Total OUTPUT

		SET @SQL = N'SELECT
			CASE    WHEN MEMBER_TRANSITION = 1 THEN ''Yes'' 
					WHEN MEMBER_TRANSITION = 0 THEN ''No'' 
					END AS GROUP_TYPE
			,ISNULL(COUNT(*),0) AS AMOUNT
			,' + CAST(@Total AS VARCHAR(12)) + ' AS TOTAL
			,ISNULL(COUNT(*) / NULLIF(' + CAST(@Total AS VARCHAR(12)) + ',0),0) AS PERCENTAGE
		FROM dbo.RX_CLAIMS_FA_REJ v
		JOIN dbo.SUP_SUPPORT_CODE c1 ON c1.CODE = v.STATUS AND c1.CODE_TYPE = ''FA_REJ_STATUS''
		--JOIN dbo.SUP_SUPPORT_CODE c2 ON c2.CODE = v.CADRE_CODE AND c2.CODE_TYPE = ''FA_REJ''
        JOIN dbo.PHAR_FA_REJECTION_CODE c2 ON c2.CODE_DESC = v.CADRE_CODE 
		'
		SET @SQL = @SQL + @WhereCondition
		SET @SQL = @SQL + N'
		GROUP BY MEMBER_TRANSITION'

		PRINT @SQL

		EXEC sp_executesql @SQL
	END
END
GO

IF @@ERROR <> 0
	AND @@TRANCOUNT > 0
	ROLLBACK TRANSACTION
GO

IF @@TRANCOUNT = 0
BEGIN
	INSERT INTO #tmpErrors (Error)
	SELECT 1

	BEGIN TRANSACTION
END
GO

PRINT N'Altering [dbo].[PHAR_FA_REJ_COUNTER]'
GO

ALTER PROCEDURE [dbo].[PHAR_FA_REJ_COUNTER] @pWeek NVARCHAR(12) = NULL
AS
BEGIN
	DECLARE @StartDay TINYINT
		,@Week1Start DATETIME
		,@Week1End DATETIME
		,@Week2Start DATETIME
		,@Week2End DATETIME
		,@Week3Start DATETIME
		,@SQL NVARCHAR(4000)

	SELECT @StartDay = CODE
	FROM dbo.SUP_SUPPORT_CODE
	WHERE CODE_TYPE = 'FA_FIRST_DAY_OF_WEEK'

	SET DATEFIRST @StartDay

	------------------------------------------------------------------------------
	--Dev only                                                                  --
	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @pWeek = '2015-05-25' --
			------------------------------------------------------------------------------

	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @pWeek = DATEADD(dd, 1 - DATEPART(dw, GETDATE()), CONVERT(DATETIME, FLOOR(CONVERT(DECIMAL(16, 4), GETDATE()))))
	SET @Week2Start = @pWeek
	SET @Week2End = DATEADD(dd, 6, @Week2Start)
	SET @Week3Start = DATEADD(dd, 1, @Week2End)
	SET @Week1Start = DATEADD(dd, - 7, @Week2Start)
	SET @Week1End = DATEADD(dd, 6, @Week1Start)
	SET @SQL = N'SELECT 
		''' + CONVERT(VARCHAR(10), @Week2Start, 101) + ' - ' + CONVERT(VARCHAR(10), @Week2End, 101) + ''' AS ''MONTH''
		,''' + CONVERT(VARCHAR(10), @Week1Start, 101) + ' - ' + CONVERT(VARCHAR(10), @Week1End, 101) + ''' AS ''YEAR''
		,ISNULL(SUM(CASE WHEN REJECTION_DATE BETWEEN ''' + CONVERT(VARCHAR(12), @Week2Start, 101) + ''' AND ''' + CONVERT(VARCHAR(12), @Week3Start, 101) + ''' THEN 1 ELSE 0 END),0) AS AMOUNT
		,ISNULL(SUM(CASE WHEN REJECTION_DATE BETWEEN ''' + CONVERT(VARCHAR(12), @Week1Start, 101) + ''' AND ''' + CONVERT(VARCHAR(12), @Week1End, 101) + ''' THEN 1 ELSE 0 END),0) AS ACCUM
	FROM RX_CLAIMS_FA_REJ v
	
	WHERE REJECTION_DATE BETWEEN ''' + CONVERT(VARCHAR(10), @Week1Start, 101) + ''' AND ''' + CONVERT(VARCHAR(10), @Week2End, 101) + ''' 
	AND IGNORE = 0 
    AND CLAIM_ACCEPTED = 0
	'

	PRINT @SQL

	EXEC sp_executesql @SQL
END
GO

IF @@ERROR <> 0
	AND @@TRANCOUNT > 0
	ROLLBACK TRANSACTION
GO

IF @@TRANCOUNT = 0
BEGIN
	INSERT INTO #tmpErrors (Error)
	SELECT 1

	BEGIN TRANSACTION
END
GO

PRINT N'Altering [dbo].[PHAR_FA_REJ_DETAIL]'
GO

ALTER PROCEDURE [dbo].[PHAR_FA_REJ_DETAIL] @pWeek NVARCHAR(12) = NULL
	,@pFieldName NVARCHAR(50) = NULL
	,@pDay NVARCHAR(3) = NULL
	,@pGroupField NVARCHAR(50) = NULL
	,@pGroupValue VARCHAR(max) = NULL
	,@pDataLimit NVARCHAR(10) = ''
	,@pOffSet NVARCHAR(10) = ''
AS
BEGIN
	DECLARE @Total DECIMAL(12, 2)
		,@StartDate DATETIME
		,@EndDate DATETIME
		,@StartDay TINYINT
		,@DayNo TINYINT
		,@TrueStartDay TINYINT
		,@WhereCondition NVARCHAR(500)
		,@SQL NVARCHAR(4000)
		,@OffsetText NVARCHAR(1000) = ''

	SELECT @StartDay = CODE
	FROM dbo.SUP_SUPPORT_CODE
	WHERE CODE_TYPE = 'FA_FIRST_DAY_OF_WEEK'

	SET DATEFIRST @StartDay

	------------------------------------------------------------------------------
	--Dev only                                                                  --
	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @pWeek = '2015-05-25' --
			------------------------------------------------------------------------------

	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @StartDate = DATEADD(dd, - 7, DATEADD(dd, 1 - DATEPART(dw, GETDATE()), CONVERT(DATETIME, FLOOR(CONVERT(DECIMAL(16, 4), GETDATE())))))
	ELSE
		SET @StartDate = CAST(@pWeek AS DATETIME)

	SET @EndDate = DATEADD(dd, 6, @StartDate)

	IF @pDay IS NOT NULL
		AND @pDay <> ''
	BEGIN
		SET @DayNo = CASE 
				WHEN @pDay = 'Mon'
					THEN 1
				WHEN @pDay = 'Tue'
					THEN 2
				WHEN @pDay = 'Wed'
					THEN 3
				WHEN @pDay = 'Thu'
					THEN 4
				WHEN @pDay = 'Fri'
					THEN 5
				WHEN @pDay = 'Sat'
					THEN 6
				WHEN @pDay = 'Sun'
					THEN 7
				END
		SET @TrueStartDay = DATEPART(dw, @StartDate) + (@StartDay - 1)

		IF @DayNo >= @TrueStartDay
			SET @StartDate = DATEADD(dd, (@DayNo - @TrueStartDay), @StartDate)

		IF @DayNo < @TrueStartDay
			SET @StartDate = DATEADD(dd, 7 - (@TrueStartDay - @DayNo), @StartDate)
		SET @EndDate = @StartDate
	END

	IF @pFieldName IS NULL
		OR @pFieldName = ''
		SET @pFieldName = 'PROTECTED_CLASS_COUNT'

	--IF @pGroupValue is null or @pGroupValue = '' set  @pGroupValue = 'Claim paid more than it should pay|Identify patient who refill drug too often'
	IF @pGroupField = 'TRANSITION'
		SET @pGroupValue = REPLACE(REPLACE(@pGroupValue, 'No', '0'), 'Yes', '1')
	SET @WhereCondition = 'WHERE CLAIM_ACCEPTED = 0 AND IGNORE = 0 '

	IF @pFieldName = 'PROTECTED_CLASS_PROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 0 AND c2.CODE_TYPE_DESC = ''Protected Class'' '

	IF @pFieldName = 'PROTECTED_CLASS_IMPROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 1 AND c2.CODE_TYPE_DESC = ''Protected Class'' '

	IF @pFieldName = 'PROTECTED_CLASS_OPEN_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE_TYPE_DESC = ''Protected Class'' AND c1.CODE = ''1'' '

	IF @pFieldName = 'PROTECTED_CLASS_PENDING_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE_TYPE_DESC = ''Protected Class'' AND c1.CODE = ''2'' '

	IF @pFieldName = 'PROTECTED_CLASS_RESOLVED_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE_TYPE_DESC = ''Protected Class'' AND c1.CODE = ''3'' '

	IF @pFieldName = 'PRIOR_AUTH_PROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 0 AND c2.CODE_TYPE_DESC = ''Prior Authorization'' '

	IF @pFieldName = 'PRIOR_AUTH_IMPROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 1 AND c2.CODE_TYPE_DESC = ''Prior Authorization'' '

	IF @pFieldName = 'PRIOR_AUTH_OPEN_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE_TYPE_DESC = ''Prior Authorization'' AND c1.CODE = ''1'' '

	IF @pFieldName = 'PRIOR_AUTH_PENDING_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE_TYPE_DESC = ''Prior Authorization'' AND c1.CODE = ''2'' '

	IF @pFieldName = 'PRIOR_AUTH_RESOLVED_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE_TYPE_DESC = ''Prior Authorization'' AND c1.CODE = ''3'' '

	IF @pFieldName = 'STEP_THERAPY_PROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 0 AND c2.CODE_TYPE_DESC = ''Step Therapy'' '

	IF @pFieldName = 'STEP_THERAPY_IMPROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 1 AND c2.CODE_TYPE_DESC = ''Step Therapy'' '

	IF @pFieldName = 'STEP_THERAPY_OPEN_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE_TYPE_DESC = ''Step Therapy'' AND c1.CODE = ''1'' '

	IF @pFieldName = 'STEP_THERAPY_PENDING_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE_TYPE_DESC = ''Step Therapy'' AND c1.CODE = ''2'' '

	IF @pFieldName = 'STEP_THERAPY_RESOLVED_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE_TYPE_DESC = ''Step Therapy'' AND c1.CODE = ''3'' '

	IF @pFieldName = 'QUANTITY_LIMIT_PROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 0 AND c2.CODE_TYPE_DESC = ''Quantity Limit'' '

	IF @pFieldName = 'QUANTITY_LIMIT_IMPROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 1 AND c2.CODE_TYPE_DESC = ''Quantity Limit'' '

	IF @pFieldName = 'QUANTITY_LIMIT_OPEN_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE_TYPE_DESC = ''Quantity Limit'' AND c1.CODE = ''1'' '

	IF @pFieldName = 'QUANTITY_LIMIT_PENDING_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE_TYPE_DESC = ''Quantity Limit'' AND c1.CODE = ''2'' '

	IF @pFieldName = 'QUANTITY_LIMIT_RESOLVED_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE_TYPE_DESC = ''Quantity Limit'' AND c1.CODE = ''3'' '

	IF @pFieldName = 'NONFORMULARY_PROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 0 AND c2.CODE_TYPE_DESC = ''Nonformulary'' '

	IF @pFieldName = 'NONFORMULARY_IMPROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 1 AND c2.CODE_TYPE_DESC = ''Nonformulary'' '

	IF @pFieldName = 'NONFORMULARY_OPEN_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE_TYPE_DESC = ''Nonformulary'' AND c1.CODE = ''1'' '

	IF @pFieldName = 'NONFORMULARY_PENDING_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE_TYPE_DESC = ''Nonformulary'' AND c1.CODE = ''2'' '

	IF @pFieldName = 'NONFORMULARY_RESOLVED_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE_TYPE_DESC = ''Nonformulary'' AND c1.CODE = ''3'' '

	IF @pFieldName = 'REFILL_TOO_SOON_PROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 0 AND c2.CODE_TYPE_DESC = ''Refill Too Soon'' '

	IF @pFieldName = 'REFILL_TOO_SOON_IMPROPER_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND OUTLIER = 1 AND c2.CODE_TYPE_DESC = ''Refill Too Soon'' '

	IF @pFieldName = 'REFILL_TOO_SOON_OPEN_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE_TYPE_DESC = ''Refill Too Soon'' AND c1.CODE = ''1'' '

	IF @pFieldName = 'REFILL_TOO_SOON_PENDING_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE_TYPE_DESC = ''Refill Too Soon'' AND c1.CODE = ''2'' '

	IF @pFieldName = 'REFILL_TOO_SOON_RESOLVED_COUNT'
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE_TYPE_DESC = ''Refill Too Soon'' AND c1.CODE = ''3'' '

	IF @pGroupField <> 'TREND'
		AND ISNULL(@pGroupValue, '') <> ''
		SET @WhereCondition = @WhereCondition + ' AND c2.CODE_SUMMARY IN  (''' + replace(@pGroupValue, '|', ''',''') + ''')'

	IF @pGroupField = 'TRANSITION'
		SET @WhereCondition = REPLACE(@WhereCondition, 'c2.CODE_SUMMARY', 'v.MEMBER_TRANSITION')
	SET @WhereCondition = @WhereCondition + 'AND  v.REJECTION_DATE BETWEEN ''' + CONVERT(VARCHAR(12), @StartDate, 101) + ''' AND ''' + CONVERT(VARCHAR(12), @EndDate, 101) + ''' '

	-- Setting Offset
	IF @pOffSet IS NULL
		OR @pOffSet = ''
		SET @pOffSet = '0'

	IF NOT (
			@pDataLimit IS NULL
			OR @pDataLimit = ''
			)
	BEGIN
		SET @OffsetText = '
            OFFSET ' + @pOffSet + ' ROWS  
            FETCH NEXT ' + @pDataLimit + ' ROWS ONLY '
	END

	SET @SQL = N'SELECT DISTINCT 
		CARD_ID
		,EXTERNAL_ID
		,REJECTION_ID AS CLAM_ID
		,CONVERT(VARCHAR(10),REJECTION_DATE,101) AS REJECTION_DATE
		,c2.CODE_TYPE_DESC
		,c1.CODE_DESC AS REJ_STATUS
		,CONVERT(VARCHAR(10),FILL_DATE,101) AS FILL_DATE
		,PLAN_ID
		,PBP
		,CASE   WHEN v.MEMBER_TRANSITION = 1 THEN ''Yes'' ELSE ''No'' END AS ''MEMBER_TRANSITION''
		,x.DRUG_NAME
		,QUANTITY_LIMIT_DAYS
		,QUANTITY_LIMIT_AMOUNT
		,NPI_PRESBR_ID
		,'''' AS DAW
		,MEMBER_FIRST_NAME
		,MEMBER_LAST_NAME
		,CONVERT(VARCHAR(10),COVERAGE_EFF_DATE,101) AS COVERAGE_EFF_DATE
		,x.DRUG_NDC_CODE AS CL_SBMD_NDC
		,ISNULL(x.DRUG_FORM,'''') AS DRUG_FORM
		,x.DRUG_ROUTE
		,x.DRUG_STRENGTH
		,REJ_DETAIL
        ,REJECTION_COUNT
	FROM RX_CLAIMS_FA_REJ v
	
	LEFT OUTER JOIN dbo.RX_NDC_DRUGS x ON x.DRUG_NDC_CODE = v.DRUG_NDC_CODE
	JOIN dbo.SUP_SUPPORT_CODE c1 ON c1.CODE = v.STATUS AND c1.CODE_TYPE = ''FA_REJ_STATUS''
	JOIN dbo.SUP_SUPPORT_CODE c2 ON c2.CODE = v.CADRE_CODE AND c2.CODE_TYPE = ''FA_REJ'' 
	'
	SET @SQL = @SQL + @WhereCondition + @OffsetText

	PRINT @SQL

	EXEC sp_executesql @SQL
END
GO

IF @@ERROR <> 0
	AND @@TRANCOUNT > 0
	ROLLBACK TRANSACTION
GO

IF @@TRANCOUNT = 0
BEGIN
	INSERT INTO #tmpErrors (Error)
	SELECT 1

	BEGIN TRANSACTION
END
GO

PRINT N'Altering [dbo].[PHAR_FA_REJ_POPUP_CLAIM]'
GO

ALTER PROCEDURE [dbo].[PHAR_FA_REJ_POPUP_CLAIM] @pKey NVARCHAR(30) = ''
	,@pWeek NVARCHAR(14) = ''
	,@pDay NVARCHAR(3) = NULL
AS
BEGIN
	DECLARE @StartDate DATETIME
		,@EndDate DATETIME
		,@StartDay TINYINT
		,@DayNo TINYINT
		,@TrueStartDay TINYINT
		,@WhereCondition NVARCHAR(500)
		,@ClaimID NVARCHAR(25) = ''
		,@SQL NVARCHAR(max) = ''

	SELECT @StartDay = CODE
	FROM dbo.SUP_SUPPORT_CODE
	WHERE CODE_TYPE = 'FA_FIRST_DAY_OF_WEEK'

	SET DATEFIRST @StartDay
	SET @ClaimID = @pKey

	--Supply default parameter value to allow proc to run and return results with no parameters specified
	IF @ClaimID IS NULL
		OR @ClaimID = ''
		SET @ClaimID = N'95733'

	PRINT @ClaimID

	------------------------------------------------------------------------------
	--Dev only                                                                  --
	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @pWeek = '2015-05-25' --
			------------------------------------------------------------------------------

	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @StartDate = DATEADD(dd, - 7, DATEADD(dd, 1 - DATEPART(dw, GETDATE()), CONVERT(DATETIME, FLOOR(CONVERT(DECIMAL(16, 4), GETDATE())))))
	ELSE
		SET @StartDate = CAST(@pWeek AS DATETIME)

	SET @EndDate = DATEADD(dd, 6, @StartDate)

	IF @pDay IS NOT NULL
		AND @pDay <> ''
	BEGIN
		SET @DayNo = CASE 
				WHEN @pDay = 'Mon'
					THEN 1
				WHEN @pDay = 'Tue'
					THEN 2
				WHEN @pDay = 'Wed'
					THEN 3
				WHEN @pDay = 'Thu'
					THEN 4
				WHEN @pDay = 'Fri'
					THEN 5
				WHEN @pDay = 'Sat'
					THEN 6
				WHEN @pDay = 'Sun'
					THEN 7
				END
		SET @TrueStartDay = DATEPART(dw, @StartDate) + (@StartDay - 1)

		IF @DayNo >= @TrueStartDay
			SET @StartDate = DATEADD(dd, (@DayNo - @TrueStartDay), @StartDate)

		IF @DayNo < @TrueStartDay
			SET @StartDate = DATEADD(dd, 7 - (@TrueStartDay - @DayNo), @StartDate)
		SET @EndDate = @StartDate
	END

	SET @WhereCondition = ' WHERE REJECTION_ID = ''' + @ClaimID + ''' '
	--Updated where clause to use week and day
	SET @WhereCondition = @WhereCondition + 'AND  v.REJECTION_DATE BETWEEN ''' + CONVERT(VARCHAR(12), @StartDate, 101) + ''' AND ''' + CONVERT(VARCHAR(12), @EndDate, 101) + ''' '
	--build select statement
	SET @SQL = 
		N'SELECT DISTINCT 
    CARD_ID
    ,EXTERNAL_ID
	,REJECTION_ID AS CLAM_ID
    ,CONVERT(VARCHAR(10),REJECTION_DATE,101) AS REJECTION_DATE
    ,c2.CODE_TYPE_DESC
    ,c1.CODE_DESC AS STATUS
    ,CONVERT(VARCHAR(10),FILL_DATE,101) AS FILL_DATE
    ,PLAN_ID
    ,PBP
    ,CASE   WHEN v.MEMBER_TRANSITION = 1 THEN ''Yes'' ELSE ''No'' END AS ''MEMBER_TRANSITION''
    ,x.DRUG_NAME
    ,QUANTITY_LIMIT_DAYS
    ,QUANTITY_LIMIT_AMOUNT
    ,NPI_PRESBR_ID
    ,'''' AS DAW
    ,MEMBER_FIRST_NAME
    ,MEMBER_LAST_NAME
    ,CONVERT(VARCHAR(10),COVERAGE_EFF_DATE,101) AS COVERAGE_EFF_DATE
    ,x.DRUG_NDC_CODE
    ,ISNULL(x.DRUG_FORM,'''') AS DRUG_FORM
    ,x.DRUG_ROUTE
    ,x.DRUG_STRENGTH
		,  ISNULL(MEMBER_FIRST_NAME,'''') +'' ''+ ISNULL(MEMBER_LAST_NAME,'''') AS MEMBER_NAME
FROM RX_CLAIMS_FA_REJ v

LEFT OUTER JOIN dbo.RX_NDC_DRUGS x ON x.DRUG_NDC_CODE = v.DRUG_NDC_CODE
JOIN dbo.SUP_SUPPORT_CODE c1 ON c1.CODE = v.STATUS AND c1.CODE_TYPE = ''FA_REJ_STATUS''
JOIN dbo.SUP_SUPPORT_CODE c2 ON c2.CODE = v.CADRE_CODE AND c2.CODE_TYPE = ''FA_REJ''	' 
		+ @WhereCondition

	PRINT @SQL

	EXEC sp_executesql @SQL
END
GO

IF @@ERROR <> 0
	AND @@TRANCOUNT > 0
	ROLLBACK TRANSACTION
GO

IF @@TRANCOUNT = 0
BEGIN
	INSERT INTO #tmpErrors (Error)
	SELECT 1

	BEGIN TRANSACTION
END
GO

PRINT N'Altering [dbo].[PHAR_FA_REJ_POPUP_CLAIM_DROPDOWN]'
GO

ALTER PROCEDURE [dbo].[PHAR_FA_REJ_POPUP_CLAIM_DROPDOWN] @pKey NVARCHAR(30) = ''
	,@pWeek NVARCHAR(14) = ''
	,@pDay NVARCHAR(3) = NULL
AS
BEGIN
	DECLARE @StartDate DATETIME
		,@EndDate DATETIME
		,@StartDay TINYINT
		,@DayNo TINYINT
		,@TrueStartDay TINYINT
		,@WhereCondition NVARCHAR(500)
		,@ClaimID NVARCHAR(25) = ''
		,@SQL NVARCHAR(max) = ''

	SELECT @StartDay = CODE
	FROM dbo.SUP_SUPPORT_CODE
	WHERE CODE_TYPE = 'FA_FIRST_DAY_OF_WEEK'

	SET DATEFIRST @StartDay
	SET @ClaimID = @pKey

	--Supply default parameter value to allow proc to run and return results with no parameters specified
	IF @ClaimID IS NULL
		OR @ClaimID = ''
		SET @ClaimID = N'95733'

	PRINT @ClaimID

	------------------------------------------------------------------------------
	--Dev only                                                                  --
	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @pWeek = '2015-05-25' --
			------------------------------------------------------------------------------

	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @StartDate = DATEADD(dd, - 7, DATEADD(dd, 1 - DATEPART(dw, GETDATE()), CONVERT(DATETIME, FLOOR(CONVERT(DECIMAL(16, 4), GETDATE())))))
	ELSE
		SET @StartDate = CAST(@pWeek AS DATETIME)

	SET @EndDate = DATEADD(dd, 6, @StartDate)

	IF @pDay IS NOT NULL
		AND @pDay <> ''
	BEGIN
		SET @DayNo = CASE 
				WHEN @pDay = 'Mon'
					THEN 1
				WHEN @pDay = 'Tue'
					THEN 2
				WHEN @pDay = 'Wed'
					THEN 3
				WHEN @pDay = 'Thu'
					THEN 4
				WHEN @pDay = 'Fri'
					THEN 5
				WHEN @pDay = 'Sat'
					THEN 6
				WHEN @pDay = 'Sun'
					THEN 7
				END
		SET @TrueStartDay = DATEPART(dw, @StartDate) + (@StartDay - 1)

		IF @DayNo >= @TrueStartDay
			SET @StartDate = DATEADD(dd, (@DayNo - @TrueStartDay), @StartDate)

		IF @DayNo < @TrueStartDay
			SET @StartDate = DATEADD(dd, 7 - (@TrueStartDay - @DayNo), @StartDate)
		SET @EndDate = @StartDate
	END

	SET @WhereCondition = ' WHERE REJECTION_ID = ''' + @ClaimID + ''' '
	--Updated where clause to use week and day
	SET @WhereCondition = @WhereCondition + 'AND  v.REJECTION_DATE BETWEEN ''' + CONVERT(VARCHAR(12), @StartDate, 101) + ''' AND ''' + CONVERT(VARCHAR(12), @EndDate, 101) + ''' '
	--build select statement
	--build select statement
	SET @SQL = 
		N'SELECT     
	CASE WHEN c1.CODE = 1  THEN 
				STUFF(( SELECT '','' + CODE_DESC
				FROM dbo.SUP_SUPPORT_CODE
				WHERE CODE_TYPE = ''FA_REJ_STATUS''
				AND CODE_DESC <> ''Improper''
				ORDER BY CASE WHEN c1.CODE = 1 THEN 1
							  WHEN c2.CODE = 2 THEN 2
							  WHEN c2.CODE = 3 THEN 3
							  END
				FOR XML PATH('''')),1,1,'''')  
 
	WHEN c1.CODE  = 2 THEN 
				STUFF(( SELECT '','' + CODE_DESC
				FROM dbo.SUP_SUPPORT_CODE
				WHERE CODE_TYPE = ''FA_REJ_STATUS''
				AND CODE_DESC <> ''Improper''
				ORDER BY CASE WHEN c1.CODE = 1 THEN 3
							  WHEN c2.CODE = 2 THEN 1
							  WHEN c2.CODE = 3 THEN 2
							  END
				FOR XML PATH('''')),1,1,'''') 
	
	
	WHEN c1.CODE = 3 THEN 
				STUFF(( SELECT '','' + CODE_DESC
				FROM dbo.SUP_SUPPORT_CODE
				WHERE CODE_TYPE = ''FA_REJ_STATUS''
				AND CODE_DESC <> ''Improper''
				ORDER BY CASE WHEN c1.CODE = 1 THEN 2
							  WHEN c2.CODE = 2 THEN 3
							  WHEN c2.CODE = 3 THEN 1
							  END
				FOR XML PATH('''')),1,1,'''')
	WHEN c1.CODE = 0 THEN 
				STUFF(( SELECT '','' + CODE_DESC
				FROM dbo.SUP_SUPPORT_CODE
				WHERE CODE_TYPE = ''FA_REJ_STATUS''
				ORDER BY CASE WHEN c1.CODE = 1 THEN 1
							  WHEN c2.CODE = 2 THEN 2
							  WHEN c2.CODE = 3 THEN 3
							  WHEN c2.CODE = 0 THEN 0
							  END
				FOR XML PATH('''')),1,1,'''')
	END
	AS ''STATUS''

FROM RX_CLAIMS_FA_REJ v

LEFT OUTER JOIN dbo.RX_NDC_DRUGS x ON x.DRUG_NDC_CODE = v.DRUG_NDC_CODE
JOIN dbo.SUP_SUPPORT_CODE c1 ON c1.CODE = v.STATUS AND c1.CODE_TYPE = ''FA_REJ_STATUS''
JOIN dbo.SUP_SUPPORT_CODE c2 ON c2.CODE = v.CADRE_CODE AND c2.CODE_TYPE = ''FA_REJ''	' 
		+ @WhereCondition + 'ORDER BY REJECTION_DATE DESC,FILL_DATE DESC,EXTERNAL_ID DESC'

	PRINT @SQL

	EXEC sp_executesql @SQL
END
GO

IF @@ERROR <> 0
	AND @@TRANCOUNT > 0
	ROLLBACK TRANSACTION
GO

IF @@TRANCOUNT = 0
BEGIN
	INSERT INTO #tmpErrors (Error)
	SELECT 1

	BEGIN TRANSACTION
END
GO

PRINT N'Altering [dbo].[PHAR_FA_REJ_POPUP_CLAIM_HEAD]'
GO

ALTER PROCEDURE [dbo].[PHAR_FA_REJ_POPUP_CLAIM_HEAD] @pKey NVARCHAR(30) = ''
	,@pWeek NVARCHAR(14) = ''
	,@pDay NVARCHAR(3) = NULL
AS
BEGIN
	DECLARE @StartDate DATETIME
		,@EndDate DATETIME
		,@StartDay TINYINT
		,@DayNo TINYINT
		,@TrueStartDay TINYINT
		,@WhereCondition NVARCHAR(500)
		,@ClaimID NVARCHAR(25) = ''
		,@SQL NVARCHAR(max) = ''

	SELECT @StartDay = CODE
	FROM dbo.SUP_SUPPORT_CODE
	WHERE CODE_TYPE = 'FA_FIRST_DAY_OF_WEEK'

	SET DATEFIRST @StartDay
	SET @ClaimID = @pKey

	--Supply default parameter value to allow proc to run and return results with no parameters specified
	IF @ClaimID IS NULL
		OR @ClaimID = ''
		SET @ClaimID = N'95733'

	PRINT @ClaimID

	------------------------------------------------------------------------------
	--Dev only                                                                  --
	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @pWeek = '2015-05-25' --
			------------------------------------------------------------------------------

	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @StartDate = DATEADD(dd, - 7, DATEADD(dd, 1 - DATEPART(dw, GETDATE()), CONVERT(DATETIME, FLOOR(CONVERT(DECIMAL(16, 4), GETDATE())))))
	ELSE
		SET @StartDate = CAST(@pWeek AS DATETIME)

	SET @EndDate = DATEADD(dd, 6, @StartDate)

	IF @pDay IS NOT NULL
		AND @pDay <> ''
	BEGIN
		SET @DayNo = CASE 
				WHEN @pDay = 'Mon'
					THEN 1
				WHEN @pDay = 'Tue'
					THEN 2
				WHEN @pDay = 'Wed'
					THEN 3
				WHEN @pDay = 'Thu'
					THEN 4
				WHEN @pDay = 'Fri'
					THEN 5
				WHEN @pDay = 'Sat'
					THEN 6
				WHEN @pDay = 'Sun'
					THEN 7
				END
		SET @TrueStartDay = DATEPART(dw, @StartDate) + (@StartDay - 1)

		IF @DayNo >= @TrueStartDay
			SET @StartDate = DATEADD(dd, (@DayNo - @TrueStartDay), @StartDate)

		IF @DayNo < @TrueStartDay
			SET @StartDate = DATEADD(dd, 7 - (@TrueStartDay - @DayNo), @StartDate)
		SET @EndDate = @StartDate
	END

	SET @WhereCondition = ' WHERE REJECTION_ID = ''' + @ClaimID + ''' '
	--Updated where clause to use week and day
	SET @WhereCondition = @WhereCondition + 'AND  v.REJECTION_DATE BETWEEN ''' + CONVERT(VARCHAR(12), @StartDate, 101) + ''' AND ''' + CONVERT(VARCHAR(12), @EndDate, 101) + ''' '
	--build select statement
	SET @SQL = N'SELECT  
	''=##==#'' + c2.CODE_TYPE_DESC + ''#='' + ''=#''+ v.REJ_DETAIL + ''#==#''+ c2.CODE_SUMMARY + ''#==#Claim ID: ''+EXTERNAL_ID+''#='' AS TITLE, c2.CODE_TYPE_DESC as COLOR_PICKER
FROM RX_CLAIMS_FA_REJ v

LEFT OUTER JOIN dbo.RX_NDC_DRUGS x ON x.DRUG_NDC_CODE = v.DRUG_NDC_CODE
JOIN dbo.SUP_SUPPORT_CODE c1 ON c1.CODE = v.STATUS AND c1.CODE_TYPE = ''FA_REJ_STATUS''
JOIN dbo.SUP_SUPPORT_CODE c2 ON c2.CODE = v.CADRE_CODE AND c2.CODE_TYPE = ''FA_REJ''	' + @WhereCondition

	PRINT @SQL

	EXEC sp_executesql @SQL
END
GO

IF @@ERROR <> 0
	AND @@TRANCOUNT > 0
	ROLLBACK TRANSACTION
GO

IF @@TRANCOUNT = 0
BEGIN
	INSERT INTO #tmpErrors (Error)
	SELECT 1

	BEGIN TRANSACTION
END
GO

PRINT N'Altering [dbo].[PHAR_FA_REJ_POPUP_CLAIM_NOTES]'
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- Build by PJ
-- =============================================
ALTER PROCEDURE [dbo].[PHAR_FA_REJ_POPUP_CLAIM_NOTES] @pKey NVARCHAR(30) = ''
	,@pWeek NVARCHAR(14) = ''
	,@pDay NVARCHAR(3) = NULL
	,@pSQL NVARCHAR(max) = '' -- OUTPUT
AS
BEGIN
	DECLARE @StartDate DATETIME
		,@EndDate DATETIME
		,@StartDay TINYINT
		,@DayNo TINYINT
		,@TrueStartDay TINYINT
		,@WhereCondition NVARCHAR(500)
		,@SQL NVARCHAR(max) = ''
		,@MemberID NVARCHAR(50) = ''
		,@ClaimID NVARCHAR(25) = ''

	SELECT @StartDay = CODE
	FROM dbo.SUP_SUPPORT_CODE
	WHERE CODE_TYPE = 'FA_FIRST_DAY_OF_WEEK'

	SET DATEFIRST @StartDay
	SET @ClaimID = @pKey

	--Supply default parameter value to allow proc to run and return results with no parameters specified
	IF @ClaimID IS NULL
		OR @ClaimID = ''
		SET @ClaimID = N'96441'

	------------------------------------------------------------------------------
	--Dev only                                                                  --
	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @pWeek = '2015-05-25' --
			------------------------------------------------------------------------------

	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @StartDate = DATEADD(dd, - 7, DATEADD(dd, 1 - DATEPART(dw, GETDATE()), CONVERT(DATETIME, FLOOR(CONVERT(DECIMAL(16, 4), GETDATE())))))
	ELSE
		SET @StartDate = CAST(@pWeek AS DATETIME)

	SET @EndDate = DATEADD(dd, 6, @StartDate)

	IF @pDay IS NOT NULL
		AND @pDay <> ''
	BEGIN
		SET @DayNo = CASE 
				WHEN @pDay = 'Mon'
					THEN 1
				WHEN @pDay = 'Tue'
					THEN 2
				WHEN @pDay = 'Wed'
					THEN 3
				WHEN @pDay = 'Thu'
					THEN 4
				WHEN @pDay = 'Fri'
					THEN 5
				WHEN @pDay = 'Sat'
					THEN 6
				WHEN @pDay = 'Sun'
					THEN 7
				END
		SET @TrueStartDay = DATEPART(dw, @StartDate) + (@StartDay - 1)

		IF @DayNo >= @TrueStartDay
			SET @StartDate = DATEADD(dd, (@DayNo - @TrueStartDay), @StartDate)

		IF @DayNo < @TrueStartDay
			SET @StartDate = DATEADD(dd, 7 - (@TrueStartDay - @DayNo), @StartDate)
		SET @EndDate = @StartDate
	END

	SET @WhereCondition = ' WHERE CLAM_ID = ''' + @ClaimID + ''' '

	--I wanted to make this easily eitable, so i built two temporary tables to format notes into a single variable
	--rather than putting a nested query into the select statement
	--in the first query, we gather all notes for a claim,
	--in the second query, we concate the notes into a single string
	CREATE TABLE #tempNotes (
		CLAIM_ID BIGINT
		,[DATE] DATETIME
		,[KEY] NVARCHAR(max)
		)

	--select notes, update temp table
	SET @pSQL = 'SELECT CLAM_ID,UPDATE_STATUS_DATE,
  ''=#''+cast(UPDATE_STATUS_DATE AS NVARCHAR)+''#=''+''=#by ''+cast(UPDATE_STATUS_PERSON AS NVARCHAR)+''#=''+''=#''+CAST(NOTES AS NVARCHAR(MAX)) +''#='' AS [KEY] 
 	FROM FA_REJ_NOTES
	WHERE CLAM_ID = ''' + @ClaimID + ''' 
	ORDER BY UPDATE_STATUS_DATE'

	PRINT @pSQL

	INSERT INTO #tempNotes
	EXEC sp_executesql @pSQL

	--second formated table
	CREATE TABLE #formatedTemp (
		CLAIM_ID BIGINT
		,[KEY] NVARCHAR(max)
		)

	--query puts notes in a single string from the previous table
	SET @pSQL = ' Select distinct ST2.CLAIM_ID,
    substring(
        (
            Select '',''+ST1.[KEY]  AS [text()]
            From dbo.#tempNotes ST1
            Where ST1.CLAIM_ID  = ST2.CLAIM_ID 
            ORDER BY ST1.CLAIM_ID,ST1.DATE 
            For XML PATH ('''')' +
		--SubString is activated, 2,10000
		'        ), 2, 10000) [#tempNotes]
From dbo.#tempNotes ST2'

	INSERT INTO #formatedTemp
	EXEC sp_executesql @pSQL

	PRINT @pSQL

	--build select statement
	SET @WhereCondition = ' WHERE  REJECTION_ID = ''' + @ClaimID + ''''
	--Updated where clause to use week and day
	SET @WhereCondition = @WhereCondition + 'AND  v.REJECTION_DATE BETWEEN ''' + CONVERT(VARCHAR(12), @StartDate, 101) + ''' AND ''' + CONVERT(VARCHAR(12), @EndDate, 101) + ''' '

	PRINT @WhereCondition

	SET @SQL = N'SELECT  REJECTION_ID AS CLAM_ID,
[KEY] AS NOTES 
FROM RX_CLAIMS_FA_REJ v

LEFT JOIN #formatedTemp NOTES ON REJECTION_ID = NOTES.CLAIM_ID' + @WhereCondition

	--+' ORDER BY NOTES.UPDATE_STATUS_DATE'
	PRINT @SQL

	EXEC sp_executesql @SQL

	DROP TABLE #formatedTemp

	DROP TABLE #tempNotes
END
GO

IF @@ERROR <> 0
	AND @@TRANCOUNT > 0
	ROLLBACK TRANSACTION
GO

IF @@TRANCOUNT = 0
BEGIN
	INSERT INTO #tmpErrors (Error)
	SELECT 1

	BEGIN TRANSACTION
END
GO

PRINT N'Altering [dbo].[PHAR_FA_REJ_POPUP_DRUG_CLAIM]'
GO

ALTER PROCEDURE [dbo].[PHAR_FA_REJ_POPUP_DRUG_CLAIM] @pKey NVARCHAR(30) = ''
	,@pWeek NVARCHAR(14) = ''
	,@pDay NVARCHAR(3) = NULL
AS
BEGIN
	DECLARE @NDC NVARCHAR(11)
		,@FillDate CHAR(10)
		,@WhereCondition VARCHAR(2500) = ''
		,@GPICount NVARCHAR(10) = ''
		,@GPI NVARCHAR(16) = ''
		,@SQL NVARCHAR(MAX) = ''
		,@NDCBlankFlag NVARCHAR(1) = 'N'
		,@FlagWhereCondition NVARCHAR(200) = ''
		,@ClaimID NVARCHAR(40) = ''
		,@PlanID NVARCHAR(20) = ''
		,@PBP NVARCHAR(20) = ''
		,@StartDate DATETIME
		,@EndDate DATETIME
		,@StartDay TINYINT
		,@DayNo TINYINT
		,@TrueStartDay TINYINT

	SET @ClaimID = @pKey

	SELECT @StartDay = CODE
	FROM dbo.SUP_SUPPORT_CODE
	WHERE CODE_TYPE = 'FA_FIRST_DAY_OF_WEEK'

	SET DATEFIRST @StartDay

	--Supply default parameter value to allow proc to run and return results with no parameters specified
	IF @ClaimID IS NULL
		OR @ClaimID = ''
		SET @ClaimID = N'107810'

	PRINT @ClaimID

	------------------------------------------------------------------------------
	--Dev only                                                                  --
	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @pWeek = '2015-05-25' --
			------------------------------------------------------------------------------

	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @StartDate = DATEADD(dd, - 7, DATEADD(dd, 1 - DATEPART(dw, GETDATE()), CONVERT(DATETIME, FLOOR(CONVERT(DECIMAL(16, 4), GETDATE())))))
	ELSE
		SET @StartDate = CAST(@pWeek AS DATETIME)

	SET @EndDate = DATEADD(dd, 6, @StartDate)

	IF @pDay IS NOT NULL
		AND @pDay <> ''
	BEGIN
		SET @DayNo = CASE 
				WHEN @pDay = 'Mon'
					THEN 1
				WHEN @pDay = 'Tue'
					THEN 2
				WHEN @pDay = 'Wed'
					THEN 3
				WHEN @pDay = 'Thu'
					THEN 4
				WHEN @pDay = 'Fri'
					THEN 5
				WHEN @pDay = 'Sat'
					THEN 6
				WHEN @pDay = 'Sun'
					THEN 7
				END
		SET @TrueStartDay = DATEPART(dw, @StartDate) + (@StartDay - 1)

		IF @DayNo >= @TrueStartDay
			SET @StartDate = DATEADD(dd, (@DayNo - @TrueStartDay), @StartDate)

		IF @DayNo < @TrueStartDay
			SET @StartDate = DATEADD(dd, 7 - (@TrueStartDay - @DayNo), @StartDate)
		SET @EndDate = @StartDate
	END

	--Set internal parameters based on REJECTION_ID
	SELECT @NDC = DRUG_NDC_CODE
	FROM RX_CLAIMS_FA_REJ
	WHERE REJECTION_ID = @ClaimID
		AND IGNORE = 0

	SELECT @FillDate = FILL_DATE
	FROM RX_CLAIMS_FA_REJ
	WHERE REJECTION_ID = @ClaimID
		AND IGNORE = 0

	SELECT @PlanID = PLAN_ID
	FROM RX_CLAIMS_FA_REJ
	WHERE REJECTION_ID = @ClaimID
		AND IGNORE = 0

	SELECT @PBP = PBP
	FROM RX_CLAIMS_FA_REJ
	WHERE REJECTION_ID = @ClaimID
		AND IGNORE = 0

	PRINT @NDC

	SET @WhereCondition = ' REJECTION_ID = ''' + @ClaimID + ''' '
	SET @WhereCondition = @WhereCondition + 'AND  v.REJECTION_DATE BETWEEN ''' + CONVERT(VARCHAR(12), @StartDate, 101) + ''' AND ''' + CONVERT(VARCHAR(12), @EndDate, 101) + ''' '
	SET @FlagWhereCondition = ' DRUGS.DRUG_NDC_CODE = ''' + @NDC + ''' '
	--build select statement
	SET @SQL = 
		N'SELECT TOP 1
	    --RELATED_NDC
        DRUGS.DRUG_NDC_CODE
	    ,DRUGS.DRUG_NAME
	    ,CODE AS MEDI_FORM
	    ,CODE_DESC AS MEDI_ROUTE
        ,DRUGS.DRUG_ROUTE
	    ,PLAN_FORM.EFFECTIVE_DATE
	    ,CASE WHEN UPPER(DRUGS.DRUG_GENERIC_FLAG) = ''Y'' THEN ''G'' ELSE ''B'' END   as BRAND_FLAG
        ,DRUGS.DRUG_GENERIC_FLAG
	    ,ISNULL(PLAN_FORM.TIER_LEVEL,'''')  AS TIER_LEVEL
		,ISNULL(DRUG_ROUTE_LABEL,'''') AS DRUG_ROUTE_LABEL
	    ,DRUGS.DRUG_OTC_FLAG AS OTC_FLAG 
        ,PLAN_FORM.QUANTITY_LIMIT_AMOUNT
        ,PLAN_FORM.QUANTITY_LIMIT_DAYS
        ,PLAN_FORM.STEP_THERAPY_TYPE
	    ,ISNULL(CAST(PLAN_FORM.STEP_THERAPY_STEP_VALUE AS NVARCHAR),'''') AS STEP_THERAPY_STEP_VALUE
        ,PLAN_FORM.STEP_THERAPY_GROUP_DESC
	    ,ISNULL(PLAN_FORM.PRIOR_AUTHORIZATION_TYPE,'''') AS  PRIOR_AUTHORIZATION_TYPE
        ,PLAN_FORM.PRIOR_AUTHORIZATION_GROUP_DESC
        ,FORMULARY_TYPE
        ,DRUGS.DRUG_LATEST_RXCUI AS RXCUI
        ,ISNULL(CONVERT(VARCHAR(12),PLAN_FORM.EFFECTIVE_DATE,101),'''') AS EFFECTIVE_DATE
        ,ISNULL(CONVERT(VARCHAR(12),PLAN_FORM.TERMINATION_DATE,101),'''') AS TERMINATION_DATE
        ,CASE WHEN FRF.FORMULARY_ID IS NULL OR PLAN_FORM.EFFECTIVE_DATE LIKE''DEL%'' THEN ''NO'' ELSE ''YES'' END AS COVERED 
	    ,(SELECT CASE WHEN FORMULARY_ID = ''PARTD''  THEN ''YES'' ELSE ''NO'' END AS PART_D_COVERED 
		    FROM RX_NDC_DRUGS DRUGS 
			    left JOIN PLAN_DRUG_FORMULARY PLAN_FORM ON DRUGS.GNPR_ID LIKE '''' + PLAN_FORM.GPI_10_ID + ''%'' + '''' AND DRUGS.DRUG_FORM = PLAN_FORM.DRUG_FORM
						    AND DRUGS.DRUG_ROUTE = PLAN_FORM.DRUG_ROUTE AND DRUGS.DRUG_OTC_FLAG = PLAN_FORM.DRUG_OTC_FLAG AND DRUGS.DRUG_GENERIC_FLAG = PLAN_FORM.DRUG_GENERIC_FLAG 
						    AND PLAN_FORM.FORMULARY_ID = ''PARTD''  AND  ''' 
		+ @FillDate + '''BETWEEN EFFECTIVE_DATE AND TERMINATION_DATE
			    LEFT JOIN (SELECT CODE,CODE_DESC,CODE_TYPE_DESC AS DRUG_ROUTE_LABEL FROM SUP_SUPPORT_CODE WHERE CODE_TYPE = ''DRUG_FORM'') C ON DRUGS.DRUG_FORM = CODE AND DRUGS.DRUG_ROUTE = CODE_DESC
			    WHERE' + @FlagWhereCondition + ') AS PART_D_COVERED '
	SET @SQL = @SQL + '
	    ,(SELECT CASE WHEN FORMULARY_ID = ''SPECD''  THEN ''YES'' ELSE ''NO'' END AS PART_D_COVERED 
		    FROM RX_NDC_DRUGS DRUGS 
			    left JOIN PLAN_DRUG_FORMULARY PLAN_FORM ON DRUGS.GNPR_ID LIKE '''' + PLAN_FORM.GPI_10_ID + ''%'' + '''' AND DRUGS.DRUG_FORM = PLAN_FORM.DRUG_FORM
						    AND DRUGS.DRUG_ROUTE = PLAN_FORM.DRUG_ROUTE AND DRUGS.DRUG_OTC_FLAG = PLAN_FORM.DRUG_OTC_FLAG AND DRUGS.DRUG_GENERIC_FLAG = PLAN_FORM.DRUG_GENERIC_FLAG 
						    AND PLAN_FORM.FORMULARY_ID = ''SPECD''  AND  ''' + @FillDate + ''' BETWEEN EFFECTIVE_DATE AND TERMINATION_DATE
			    LEFT JOIN (SELECT CODE,CODE_DESC,CODE_TYPE_DESC AS DRUG_ROUTE_LABEL FROM SUP_SUPPORT_CODE WHERE CODE_TYPE = ''DRUG_FORM'') C ON DRUGS.DRUG_FORM = CODE AND DRUGS.DRUG_ROUTE = CODE_DESC
			    WHERE' + @FlagWhereCondition + ') AS SPECD_COVERED '
	SET @SQL = @SQL + '
	    ,(SELECT CASE WHEN FORMULARY_ID = ''PROTD''  THEN ''YES'' ELSE ''NO'' END AS PROTD_COVERED 
		    FROM RX_NDC_DRUGS DRUGS 
			    left JOIN PLAN_DRUG_FORMULARY PLAN_FORM ON DRUGS.GNPR_ID LIKE '''' + PLAN_FORM.GPI_10_ID + ''%'' + '''' AND DRUGS.DRUG_FORM = PLAN_FORM.DRUG_FORM
						    AND DRUGS.DRUG_ROUTE = PLAN_FORM.DRUG_ROUTE AND DRUGS.DRUG_OTC_FLAG = PLAN_FORM.DRUG_OTC_FLAG AND DRUGS.DRUG_GENERIC_FLAG = PLAN_FORM.DRUG_GENERIC_FLAG 
						    AND PLAN_FORM.FORMULARY_ID = ''PROTD''  AND  ''' + @FillDate + '''BETWEEN EFFECTIVE_DATE AND TERMINATION_DATE
			    LEFT JOIN (SELECT CODE,CODE_DESC,CODE_TYPE_DESC AS DRUG_ROUTE_LABEL FROM SUP_SUPPORT_CODE WHERE CODE_TYPE = ''DRUG_FORM'') C ON DRUGS.DRUG_FORM = CODE AND DRUGS.DRUG_ROUTE = CODE_DESC
			    WHERE' + @FlagWhereCondition + ') AS PROTD_COVERED '
	SET @SQL = @SQL + N'FROM dbo.RX_CLAIMS_FA_REJ v
    LEFT JOIN dbo.RX_NDC_DRUGS DRUGS ON DRUGS.DRUG_NDC_CODE = v.DRUG_NDC_CODE
    LEFT OUTER JOIN dbo.MB_MEMBER_ELIGIBILITY e ON v.MEMBER_CK = e.MEMBER_CK AND FILL_DATE  BETWEEN e.EFFECTIVE_DATE AND e.TERMINATION_DATE 
		AND v.PLAN_ID = e.PLAN_ID and v.PBP = e.PBP	
   	LEFT OUTER JOIN PLAN_DRUG_FORMULARY PLAN_FORM ON DRUGS.GNPR_ID LIKE '''' + PLAN_FORM.GPI_10_ID + ''%'' + '''' AND DRUGS.DRUG_FORM = PLAN_FORM.DRUG_FORM
		AND DRUGS.DRUG_ROUTE = PLAN_FORM.DRUG_ROUTE AND DRUGS.DRUG_OTC_FLAG = PLAN_FORM.DRUG_OTC_FLAG AND DRUGS.DRUG_GENERIC_FLAG = PLAN_FORM.DRUG_GENERIC_FLAG 
		AND PLAN_FORM.FORMULARY_ID = e.PLAN_ID  AND  ''' + @FillDate + '''BETWEEN PLAN_FORM.EFFECTIVE_DATE AND PLAN_FORM.TERMINATION_DATE 
	LEFT OUTER JOIN PLAN_HPMS_FORMULARY_SUBMISSIONS FRF ON PLAN_FORM.THERAPEUTIC_CATEGORY_NAME = FRF.THERAPEUTIC_CATEGORY_NAME AND FRF.FORMULARY_ID = ''' + @PlanID + 
		''' AND
				PLAN_FORM.THERAPEUTIC_CLASS_NAME = FRF.THERAPEUTIC_CLASS_NAME AND PLAN_FORM.RELATED_NDC = FRF.RELATED_NDC
	LEFT JOIN (SELECT CODE,CODE_DESC,CODE_TYPE_DESC AS DRUG_ROUTE_LABEL FROM SUP_SUPPORT_CODE WHERE CODE_TYPE = ''DRUG_FORM'') C ON DRUGS.DRUG_FORM = CODE AND DRUGS.DRUG_ROUTE = CODE_DESC
	WHERE' + @WhereCondition + '
	order BY PLAN_FORM.EFFECTIVE_DATE DESC'

	PRINT CAST(@SQL AS TEXT)

	EXEC sp_executesql @SQL
END
GO

IF @@ERROR <> 0
	AND @@TRANCOUNT > 0
	ROLLBACK TRANSACTION
GO

IF @@TRANCOUNT = 0
BEGIN
	INSERT INTO #tmpErrors (Error)
	SELECT 1

	BEGIN TRANSACTION
END
GO

PRINT N'Altering [dbo].[PHAR_FA_REJ_POPUP_DRUG_CLAIM_TITLE]'
GO

ALTER PROCEDURE [dbo].[PHAR_FA_REJ_POPUP_DRUG_CLAIM_TITLE] @pKey NVARCHAR(30) = ''
	,@pWeek NVARCHAR(14) = ''
	,@pDay NVARCHAR(3) = NULL
AS
BEGIN
	DECLARE @NDC NVARCHAR(11)
		,@WhereCondition VARCHAR(2500) = ''
		,@GPICount NVARCHAR(10) = ''
		,@GPI NVARCHAR(16) = ''
		,@SQL NVARCHAR(MAX) = ''
		,@FlagWhereCondition NVARCHAR(200) = ''
		,@ClaimID NVARCHAR(40) = ''
		,@PlanID NVARCHAR(20) = ''
		,@PBP NVARCHAR(20) = ''
		,@ClaimFillDate NVARCHAR(12) = ''
		,@StartDate DATETIME
		,@EndDate DATETIME
		,@StartDay TINYINT
		,@DayNo TINYINT
		,@TrueStartDay TINYINT

	--set default values
	SET @ClaimID = @pKey

	SELECT @StartDay = CODE
	FROM dbo.SUP_SUPPORT_CODE
	WHERE CODE_TYPE = 'FA_FIRST_DAY_OF_WEEK'

	SET DATEFIRST @StartDay

	--Supply default parameter value to allow proc to run and return results with no parameters specified
	IF @ClaimID IS NULL
		OR @ClaimID = ''
		SET @ClaimID = N'95733'

	PRINT @ClaimID

	------------------------------------------------------------------------------
	--Dev only                                                                  --
	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @pWeek = '2015-05-25' --
			------------------------------------------------------------------------------

	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @StartDate = DATEADD(dd, - 7, DATEADD(dd, 1 - DATEPART(dw, GETDATE()), CONVERT(DATETIME, FLOOR(CONVERT(DECIMAL(16, 4), GETDATE())))))
	ELSE
		SET @StartDate = CAST(@pWeek AS DATETIME)

	SET @EndDate = DATEADD(dd, 6, @StartDate)

	IF @pDay IS NOT NULL
		AND @pDay <> ''
	BEGIN
		SET @DayNo = CASE 
				WHEN @pDay = 'Mon'
					THEN 1
				WHEN @pDay = 'Tue'
					THEN 2
				WHEN @pDay = 'Wed'
					THEN 3
				WHEN @pDay = 'Thu'
					THEN 4
				WHEN @pDay = 'Fri'
					THEN 5
				WHEN @pDay = 'Sat'
					THEN 6
				WHEN @pDay = 'Sun'
					THEN 7
				END
		SET @TrueStartDay = DATEPART(dw, @StartDate) + (@StartDay - 1)

		IF @DayNo >= @TrueStartDay
			SET @StartDate = DATEADD(dd, (@DayNo - @TrueStartDay), @StartDate)

		IF @DayNo < @TrueStartDay
			SET @StartDate = DATEADD(dd, 7 - (@TrueStartDay - @DayNo), @StartDate)
		SET @EndDate = @StartDate
	END

	--Set internal parameters based on REJECTION_ID
	SELECT @NDC = DRUG_NDC_CODE
	FROM RX_CLAIMS_FA_REJ
	WHERE REJECTION_ID = @ClaimID
		AND IGNORE = 0

	SELECT @ClaimFillDate = FILL_DATE
	FROM RX_CLAIMS_FA_REJ
	WHERE REJECTION_ID = @ClaimID
		AND IGNORE = 0

	SELECT @PlanID = PLAN_ID
	FROM RX_CLAIMS_FA_REJ
	WHERE REJECTION_ID = @ClaimID
		AND IGNORE = 0

	SELECT @PBP = PBP
	FROM RX_CLAIMS_FA_REJ
	WHERE REJECTION_ID = @ClaimID
		AND IGNORE = 0

	--Set default formulary name
	PRINT @ClaimFillDate

	SET @WhereCondition = ' WHERE REJECTION_ID = ''' + @ClaimID + ''' '
	SET @WhereCondition = @WhereCondition + 'AND  v.REJECTION_DATE BETWEEN ''' + CONVERT(VARCHAR(12), @StartDate, 101) + ''' AND ''' + CONVERT(VARCHAR(12), @EndDate, 101) + ''' '
	--build select statement
	SET @SQL = 
		'SELECT ''=#Covered: ''+COVERED+''#==#Part D Covered: ''+PART_D_COVERED+''#==#Specialty: ''+SPECD_COVERED+''#==#Protected: ''+PROTD_COVERED+''#='' AS TITLE
,NULL AS COLOR_PICKER  
	FROM
	(SELECT
		ROW_NUMBER() OVER (PARTITION BY DRUGS.DRUG_NDC_CODE,PLAN_FORM.EFFECTIVE_DATE,PLAN_FORM.TERMINATION_DATE, REJECTION_ID ORDER BY PLAN_FORM.EFFECTIVE_DATE DESC) AS RN
		,REJECTION_DATE
		,FILL_DATE
		,EXTERNAL_ID
		,CASE WHEN FORMULARY_ID IS NULL  THEN ''NO'' ELSE ''YES'' END AS COVERED
	    ,(SELECT CASE WHEN FORMULARY_ID = ''PARTD''  THEN ''YES'' ELSE ''NO'' END AS PART_D_COVERED 
				FROM RX_NDC_DRUGS DRUGS 
					left JOIN PLAN_DRUG_FORMULARY PLAN_FORM ON DRUGS.GNPR_ID LIKE '''' + PLAN_FORM.GPI_10_ID + ''%'' + '''' AND DRUGS.DRUG_FORM = PLAN_FORM.DRUG_FORM
								AND DRUGS.DRUG_ROUTE = PLAN_FORM.DRUG_ROUTE AND DRUGS.DRUG_OTC_FLAG = PLAN_FORM.DRUG_OTC_FLAG AND DRUGS.DRUG_GENERIC_FLAG = PLAN_FORM.DRUG_GENERIC_FLAG 
								AND PLAN_FORM.FORMULARY_ID = ''PARTD''  AND FILL_DATE BETWEEN EFFECTIVE_DATE AND TERMINATION_DATE 
					LEFT JOIN (SELECT CODE,CODE_DESC,CODE_TYPE_DESC AS DRUG_ROUTE_LABEL FROM SUP_SUPPORT_CODE WHERE CODE_TYPE = ''DRUG_FORM'') C ON DRUGS.DRUG_FORM = CODE AND DRUGS.DRUG_ROUTE = CODE_DESC
					WHERE DRUGS.DRUG_NDC_CODE = v.DRUG_NDC_CODE) AS PART_D_COVERED '
	SET @SQL = @SQL + '
		,(SELECT CASE WHEN FORMULARY_ID = ''SPECD''  THEN ''YES'' ELSE ''NO'' END AS PART_D_COVERED 
			FROM RX_NDC_DRUGS DRUGS 
				left JOIN PLAN_DRUG_FORMULARY PLAN_FORM ON DRUGS.GNPR_ID LIKE '''' + PLAN_FORM.GPI_10_ID + ''%'' + '''' AND DRUGS.DRUG_FORM = PLAN_FORM.DRUG_FORM
							AND DRUGS.DRUG_ROUTE = PLAN_FORM.DRUG_ROUTE AND DRUGS.DRUG_OTC_FLAG = PLAN_FORM.DRUG_OTC_FLAG AND DRUGS.DRUG_GENERIC_FLAG = PLAN_FORM.DRUG_GENERIC_FLAG 
							AND PLAN_FORM.FORMULARY_ID = ''SPECD''  AND FILL_DATE BETWEEN EFFECTIVE_DATE AND TERMINATION_DATE  
				LEFT JOIN (SELECT CODE,CODE_DESC,CODE_TYPE_DESC AS DRUG_ROUTE_LABEL FROM SUP_SUPPORT_CODE WHERE CODE_TYPE = ''DRUG_FORM'') C ON DRUGS.DRUG_FORM = CODE AND DRUGS.DRUG_ROUTE = CODE_DESC
				WHERE DRUGS.DRUG_NDC_CODE = v.DRUG_NDC_CODE) AS SPECD_COVERED '
	SET @SQL = @SQL + '
		,(SELECT CASE WHEN FORMULARY_ID = ''PROTD'' THEN ''YES'' ELSE ''NO'' END AS PROTD_COVERED 
			FROM RX_NDC_DRUGS DRUGS 
			left JOIN PLAN_DRUG_FORMULARY PLAN_FORM ON DRUGS.GNPR_ID LIKE '''' + PLAN_FORM.GPI_10_ID + ''%'' + '''' AND DRUGS.DRUG_FORM = PLAN_FORM.DRUG_FORM
						AND DRUGS.DRUG_ROUTE = PLAN_FORM.DRUG_ROUTE AND DRUGS.DRUG_OTC_FLAG = PLAN_FORM.DRUG_OTC_FLAG AND DRUGS.DRUG_GENERIC_FLAG = PLAN_FORM.DRUG_GENERIC_FLAG 
						AND PLAN_FORM.FORMULARY_ID = ''PROTD''  AND  FILL_DATE BETWEEN EFFECTIVE_DATE AND TERMINATION_DATE 
			LEFT JOIN (SELECT CODE,CODE_DESC,CODE_TYPE_DESC AS DRUG_ROUTE_LABEL FROM SUP_SUPPORT_CODE WHERE CODE_TYPE = ''DRUG_FORM'') C ON DRUGS.DRUG_FORM = CODE AND DRUGS.DRUG_ROUTE = CODE_DESC
			WHERE DRUGS.DRUG_NDC_CODE = v.DRUG_NDC_CODE) AS PROTD_COVERED 
'
	SET @SQL = @SQL + '
   FROM dbo.RX_CLAIMS_FA_REJ v
   JOIN RX_NDC_DRUGS DRUGS on DRUGS.DRUG_NDC_CODE = v.DRUG_NDC_CODE
	left JOIN PLAN_DRUG_FORMULARY PLAN_FORM ON DRUGS.GNPR_ID LIKE '''' + PLAN_FORM.GPI_10_ID + ''%'' + '''' AND DRUGS.DRUG_FORM = PLAN_FORM.DRUG_FORM
				AND DRUGS.DRUG_ROUTE = PLAN_FORM.DRUG_ROUTE AND DRUGS.DRUG_OTC_FLAG = PLAN_FORM.DRUG_OTC_FLAG AND DRUGS.DRUG_GENERIC_FLAG = PLAN_FORM.DRUG_GENERIC_FLAG 
				AND PLAN_FORM.FORMULARY_ID = PLAN_FORM.PLAN_ID AND FILL_DATE BETWEEN EFFECTIVE_DATE AND TERMINATION_DATE 
	LEFT JOIN (SELECT CODE,CODE_DESC,CODE_TYPE_DESC AS DRUG_ROUTE_LABEL FROM SUP_SUPPORT_CODE WHERE CODE_TYPE = ''DRUG_FORM'') C ON DRUGS.DRUG_FORM = CODE AND DRUGS.DRUG_ROUTE = CODE_DESC
	JOIN dbo.SUP_SUPPORT_CODE c2 ON c2.CODE = v.CADRE_CODE AND c2.CODE_TYPE = ''FA_REJ''
	'
	SET @SQL = @SQL + @WhereCondition + ') TEMP
	WHERE RN = 1
	ORDER BY REJECTION_DATE DESC,FILL_DATE DESC,EXTERNAL_ID DESC'

	PRINT cast(@SQL AS TEXT)

	EXEC sp_executesql @SQL
END
GO

IF @@ERROR <> 0
	AND @@TRANCOUNT > 0
	ROLLBACK TRANSACTION
GO

IF @@TRANCOUNT = 0
BEGIN
	INSERT INTO #tmpErrors (Error)
	SELECT 1

	BEGIN TRANSACTION
END
GO

PRINT N'Altering [dbo].[PHAR_FA_REJ_POPUP_DRUG_MEMBER_TITLE]'
GO

ALTER PROCEDURE [dbo].[PHAR_FA_REJ_POPUP_DRUG_MEMBER_TITLE] @pKey NVARCHAR(30) = ''
	,@pWeek NVARCHAR(14) = ''
	,@pDay NVARCHAR(3) = NULL
AS
BEGIN
	DECLARE @NDC NVARCHAR(11)
		,@WhereCondition VARCHAR(2500) = ''
		,@StartDate DATETIME
		,@EndDate DATETIME
		,@StartDay TINYINT
		,@DayNo TINYINT
		,@TrueStartDay TINYINT
		,@SQL NVARCHAR(MAX) = ''
		,@ClaimID NVARCHAR(40) = ''
		,@PlanID NVARCHAR(20) = ''
		,@MemberID NVARCHAR(50) = ''

	--set default values
	SET @ClaimID = @pKey

	SELECT @StartDay = CODE
	FROM dbo.SUP_SUPPORT_CODE
	WHERE CODE_TYPE = 'FA_FIRST_DAY_OF_WEEK'

	SET DATEFIRST @StartDay

	--Supply default parameter value to allow proc to run and return results with no parameters specified
	IF @ClaimID IS NULL
		OR @ClaimID = ''
		SET @ClaimID = N'4'

	------------------------------------------------------------------------------
	--Dev only                                                                  --
	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @pWeek = '2015-05-25' --
			------------------------------------------------------------------------------

	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @StartDate = DATEADD(dd, - 7, DATEADD(dd, 1 - DATEPART(dw, GETDATE()), CONVERT(DATETIME, FLOOR(CONVERT(DECIMAL(16, 4), GETDATE())))))
	ELSE
		SET @StartDate = CAST(@pWeek AS DATETIME)

	SET @EndDate = DATEADD(dd, 6, @StartDate)

	IF @pDay IS NOT NULL
		AND @pDay <> ''
	BEGIN
		SET @DayNo = CASE 
				WHEN @pDay = 'Mon'
					THEN 1
				WHEN @pDay = 'Tue'
					THEN 2
				WHEN @pDay = 'Wed'
					THEN 3
				WHEN @pDay = 'Thu'
					THEN 4
				WHEN @pDay = 'Fri'
					THEN 5
				WHEN @pDay = 'Sat'
					THEN 6
				WHEN @pDay = 'Sun'
					THEN 7
				END
		SET @TrueStartDay = DATEPART(dw, @StartDate) + (@StartDay - 1)

		IF @DayNo >= @TrueStartDay
			SET @StartDate = DATEADD(dd, (@DayNo - @TrueStartDay), @StartDate)

		IF @DayNo < @TrueStartDay
			SET @StartDate = DATEADD(dd, 7 - (@TrueStartDay - @DayNo), @StartDate)
		SET @EndDate = @StartDate
	END

	--Condition to retrieve member id
	SET @MemberID = (
			SELECT CARD_ID
			FROM RX_CLAIMS_FA_REJ v
			INNER JOIN dbo.SUP_SUPPORT_CODE c1 ON c1.CODE = v.STATUS
				AND c1.CODE_TYPE = 'FA_REJ_STATUS'
			INNER JOIN dbo.SUP_SUPPORT_CODE c2 ON c2.CODE = v.CADRE_CODE
				AND c2.CODE_TYPE = 'FA_REJ'
			WHERE REJECTION_ID = @ClaimID
			)
	--Set internal parameters based on REJECTION_ID
	SET @WhereCondition = ' WHERE CARD_ID = ''' + @MemberID + ''' AND IGNORE = 0 '
	SET @WhereCondition = @WhereCondition + 'AND  v.REJECTION_DATE BETWEEN ''' + CONVERT(VARCHAR(12), @StartDate, 101) + ''' AND ''' + CONVERT(VARCHAR(12), @EndDate, 101) + ''' '
	--build select statement
	SET @SQL = 
		'SELECT ''=#Covered: ''+COVERED+''#==#Part D Covered: ''+PART_D_COVERED+''#==#Specialty: ''+SPECD_COVERED+''#==#Protected: ''+PROTD_COVERED+''#='' AS TITLE,NULL AS COLOR_PICKER FROM (SELECT 
		CASE WHEN FORMULARY_ID IS NULL  THEN ''NO'' ELSE ''YES'' END AS COVERED 
	           ,(SELECT CASE WHEN FORMULARY_ID = ''PARTD''  THEN ''YES'' ELSE ''NO'' END AS PART_D_COVERED 
		FROM RX_NDC_DRUGS DRUGS 
			left JOIN PLAN_DRUG_FORMULARY PLAN_FORM ON DRUGS.GNPR_ID LIKE '''' + PLAN_FORM.GPI_10_ID + ''%'' + '''' AND DRUGS.DRUG_FORM = PLAN_FORM.DRUG_FORM
						AND DRUGS.DRUG_ROUTE = PLAN_FORM.DRUG_ROUTE AND DRUGS.DRUG_OTC_FLAG = PLAN_FORM.DRUG_OTC_FLAG AND DRUGS.DRUG_GENERIC_FLAG = PLAN_FORM.DRUG_GENERIC_FLAG 
						AND PLAN_FORM.FORMULARY_ID = ''PARTD''  AND FILL_DATE BETWEEN EFFECTIVE_DATE AND TERMINATION_DATE 
			LEFT JOIN (SELECT CODE,CODE_DESC,CODE_TYPE_DESC AS DRUG_ROUTE_LABEL FROM SUP_SUPPORT_CODE WHERE CODE_TYPE = ''DRUG_FORM'') C ON DRUGS.DRUG_FORM = CODE AND DRUGS.DRUG_ROUTE = CODE_DESC
			WHERE DRUGS.DRUG_NDC_CODE = v.DRUG_NDC_CODE) AS PART_D_COVERED '
	SET @SQL = @SQL + '
		,(SELECT CASE WHEN FORMULARY_ID = ''SPECD''  THEN ''YES'' ELSE ''NO'' END AS PART_D_COVERED 
		FROM RX_NDC_DRUGS DRUGS 
			left JOIN PLAN_DRUG_FORMULARY PLAN_FORM ON DRUGS.GNPR_ID LIKE '''' + PLAN_FORM.GPI_10_ID + ''%'' + '''' AND DRUGS.DRUG_FORM = PLAN_FORM.DRUG_FORM
						AND DRUGS.DRUG_ROUTE = PLAN_FORM.DRUG_ROUTE AND DRUGS.DRUG_OTC_FLAG = PLAN_FORM.DRUG_OTC_FLAG AND DRUGS.DRUG_GENERIC_FLAG = PLAN_FORM.DRUG_GENERIC_FLAG 
						AND PLAN_FORM.FORMULARY_ID = ''SPECD''  AND FILL_DATE BETWEEN EFFECTIVE_DATE AND TERMINATION_DATE  
			LEFT JOIN (SELECT CODE,CODE_DESC,CODE_TYPE_DESC AS DRUG_ROUTE_LABEL FROM SUP_SUPPORT_CODE WHERE CODE_TYPE = ''DRUG_FORM'') C ON DRUGS.DRUG_FORM = CODE AND DRUGS.DRUG_ROUTE = CODE_DESC
			WHERE DRUGS.DRUG_NDC_CODE = v.DRUG_NDC_CODE) AS SPECD_COVERED '
	SET @SQL = @SQL + '
		,(SELECT CASE WHEN FORMULARY_ID = ''PROTD'' THEN ''YES'' ELSE ''NO'' END AS PROTD_COVERED 
		FROM RX_NDC_DRUGS DRUGS 
			left JOIN PLAN_DRUG_FORMULARY PLAN_FORM ON DRUGS.GNPR_ID LIKE '''' + PLAN_FORM.GPI_10_ID + ''%'' + '''' AND DRUGS.DRUG_FORM = PLAN_FORM.DRUG_FORM
						AND DRUGS.DRUG_ROUTE = PLAN_FORM.DRUG_ROUTE AND DRUGS.DRUG_OTC_FLAG = PLAN_FORM.DRUG_OTC_FLAG AND DRUGS.DRUG_GENERIC_FLAG = PLAN_FORM.DRUG_GENERIC_FLAG 
						AND PLAN_FORM.FORMULARY_ID = ''PROTD''  AND  FILL_DATE BETWEEN EFFECTIVE_DATE AND TERMINATION_DATE 
			LEFT JOIN (SELECT CODE,CODE_DESC,CODE_TYPE_DESC AS DRUG_ROUTE_LABEL FROM SUP_SUPPORT_CODE WHERE CODE_TYPE = ''DRUG_FORM'') C ON DRUGS.DRUG_FORM = CODE AND DRUGS.DRUG_ROUTE = CODE_DESC
			WHERE DRUGS.DRUG_NDC_CODE = v.DRUG_NDC_CODE) AS PROTD_COVERED 
			,FILL_DATE
			,EXTERNAL_ID
			,REJECTION_DATE'
	SET @SQL = @SQL + '
   FROM dbo.RX_CLAIMS_FA_REJ v
    JOIN RX_NDC_DRUGS DRUGS on DRUGS.DRUG_NDC_CODE = v.DRUG_NDC_CODE
	left JOIN PLAN_DRUG_FORMULARY PLAN_FORM ON DRUGS.GNPR_ID LIKE '''' + PLAN_FORM.GPI_10_ID + ''%'' + '''' AND DRUGS.DRUG_FORM = PLAN_FORM.DRUG_FORM
				AND DRUGS.DRUG_ROUTE = PLAN_FORM.DRUG_ROUTE AND DRUGS.DRUG_OTC_FLAG = PLAN_FORM.DRUG_OTC_FLAG AND DRUGS.DRUG_GENERIC_FLAG = PLAN_FORM.DRUG_GENERIC_FLAG 
				AND PLAN_FORM.FORMULARY_ID = v.PLAN_ID AND FILL_DATE BETWEEN EFFECTIVE_DATE AND TERMINATION_DATE 
	LEFT JOIN (SELECT CODE,CODE_DESC,CODE_TYPE_DESC AS DRUG_ROUTE_LABEL FROM SUP_SUPPORT_CODE WHERE CODE_TYPE = ''DRUG_FORM'') C ON DRUGS.DRUG_FORM = CODE AND DRUGS.DRUG_ROUTE = CODE_DESC
	JOIN dbo.SUP_SUPPORT_CODE c2 ON c2.CODE = v.CADRE_CODE AND c2.CODE_TYPE = ''FA_REJ''	
	'
	SET @SQL = @SQL + @WhereCondition + ') TEMP
	ORDER BY REJECTION_DATE DESC,FILL_DATE DESC,EXTERNAL_ID DESC'

	PRINT cast(@SQL AS TEXT)

	EXEC sp_executesql @SQL
END
GO

IF @@ERROR <> 0
	AND @@TRANCOUNT > 0
	ROLLBACK TRANSACTION
GO

IF @@TRANCOUNT = 0
BEGIN
	INSERT INTO #tmpErrors (Error)
	SELECT 1

	BEGIN TRANSACTION
END
GO

PRINT N'Altering [dbo].[PHAR_FA_REJ_POPUP_MEMBER]'
GO

ALTER PROCEDURE [dbo].[PHAR_FA_REJ_POPUP_MEMBER] @pKey NVARCHAR(30) = ''
	,@pWeek NVARCHAR(14) = ''
	,@pDay NVARCHAR(3) = NULL
AS
BEGIN
	DECLARE @StartDate DATETIME
		,@EndDate DATETIME
		,@StartDay TINYINT
		,@DayNo TINYINT
		,@TrueStartDay TINYINT
		,@WhereCondition NVARCHAR(500)
		,@SQL NVARCHAR(max) = ''
		,@MemberID NVARCHAR(50) = ''
		,@ClaimID NVARCHAR(25) = ''

	SELECT @StartDay = CODE
	FROM dbo.SUP_SUPPORT_CODE
	WHERE CODE_TYPE = 'FA_FIRST_DAY_OF_WEEK'

	SET DATEFIRST @StartDay
	SET @ClaimID = @pKey

	--Supply default parameter value to allow proc to run and return results with no parameters specified
	IF @ClaimID IS NULL
		OR @ClaimID = ''
		SET @ClaimID = N'95733'
	SET @MemberID = (
			SELECT CARD_ID
			FROM RX_CLAIMS_FA_REJ v
			INNER JOIN dbo.SUP_SUPPORT_CODE c1 ON c1.CODE = v.STATUS
				AND c1.CODE_TYPE = 'FA_REJ_STATUS'
			INNER JOIN dbo.SUP_SUPPORT_CODE c2 ON c2.CODE = v.CADRE_CODE
				AND c2.CODE_TYPE = 'FA_REJ'
			WHERE REJECTION_ID = @ClaimID
			)

	PRINT @MemberID

	------------------------------------------------------------------------------
	--Dev only                                                                  --
	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @pWeek = '2015-05-25' --
			------------------------------------------------------------------------------

	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @StartDate = DATEADD(dd, - 7, DATEADD(dd, 1 - DATEPART(dw, GETDATE()), CONVERT(DATETIME, FLOOR(CONVERT(DECIMAL(16, 4), GETDATE())))))
	ELSE
		SET @StartDate = CAST(@pWeek AS DATETIME)

	SET @EndDate = DATEADD(dd, 6, @StartDate)

	IF @pDay IS NOT NULL
		AND @pDay <> ''
	BEGIN
		SET @DayNo = CASE 
				WHEN @pDay = 'Mon'
					THEN 1
				WHEN @pDay = 'Tue'
					THEN 2
				WHEN @pDay = 'Wed'
					THEN 3
				WHEN @pDay = 'Thu'
					THEN 4
				WHEN @pDay = 'Fri'
					THEN 5
				WHEN @pDay = 'Sat'
					THEN 6
				WHEN @pDay = 'Sun'
					THEN 7
				END
		SET @TrueStartDay = DATEPART(dw, @StartDate) + (@StartDay - 1)

		IF @DayNo >= @TrueStartDay
			SET @StartDate = DATEADD(dd, (@DayNo - @TrueStartDay), @StartDate)

		IF @DayNo < @TrueStartDay
			SET @StartDate = DATEADD(dd, 7 - (@TrueStartDay - @DayNo), @StartDate)
		SET @EndDate = @StartDate
	END

	SET @WhereCondition = ' WHERE CARD_ID = ''' + @MemberID + ''' AND IGNORE = 0 '
	--Updated where clause to use week and day
	SET @WhereCondition = @WhereCondition + 'AND  v.REJECTION_DATE BETWEEN ''' + CONVERT(VARCHAR(12), @StartDate, 101) + ''' AND ''' + CONVERT(VARCHAR(12), @EndDate, 101) + ''' '

	PRINT @WhereCondition

	--build select statement
	SET @SQL = 
		N'SELECT DISTINCT 
	v.REJECTION_DATE as ValidationDate
    ,CARD_ID
    ,EXTERNAL_ID
	,REJECTION_ID AS CLAM_ID
    ,CONVERT(VARCHAR(10),REJECTION_DATE,101) AS REJECTION_DATE
    ,c2.CODE_TYPE_DESC
    ,c1.CODE_DESC AS REJ_STATUS
    ,CONVERT(VARCHAR(10),FILL_DATE,101) AS FILL_DATE
    ,PLAN_ID
    ,PBP
    ,CASE   WHEN v.MEMBER_TRANSITION = 1 THEN ''Yes'' ELSE ''No'' END AS ''MEMBER_TRANSITION''
    ,v.DRUG_NAME
    ,QUANTITY_LIMIT_DAYS
    ,QUANTITY_LIMIT_AMOUNT
    ,NPI_PRESBR_ID
    ,'''' AS DAW
    ,MEMBER_FIRST_NAME
    ,MEMBER_LAST_NAME
    ,CONVERT(VARCHAR(10),COVERAGE_EFF_DATE,101) AS COVERAGE_EFF_DATE
    ,v.DRUG_NDC_CODE
    ,ISNULL(x.DRUG_FORM,'''') AS DRUG_FORM
    ,v.DRUG_ROUTE
    ,v.DRUG_STRENGTH
	,ISNULL(MEMBER_FIRST_NAME,'''') +'' ''+  ISNULL(MEMBER_LAST_NAME,'''') AS MEMBER_NAME
FROM RX_CLAIMS_FA_REJ v

LEFT OUTER JOIN dbo.RX_NDC_DRUGS x ON x.DRUG_NDC_CODE = v.DRUG_NDC_CODE
JOIN dbo.SUP_SUPPORT_CODE c1 ON c1.CODE = v.STATUS AND c1.CODE_TYPE = ''FA_REJ_STATUS''
JOIN dbo.SUP_SUPPORT_CODE c2 ON c2.CODE = v.CADRE_CODE AND c2.CODE_TYPE = ''FA_REJ''	' 
		+ @WhereCondition + 'ORDER BY v.REJECTION_DATE DESC,FILL_DATE DESC,EXTERNAL_ID DESC'

	PRINT @SQL

	EXEC sp_executesql @SQL
END
GO

IF @@ERROR <> 0
	AND @@TRANCOUNT > 0
	ROLLBACK TRANSACTION
GO

IF @@TRANCOUNT = 0
BEGIN
	INSERT INTO #tmpErrors (Error)
	SELECT 1

	BEGIN TRANSACTION
END
GO

PRINT N'Altering [dbo].[PHAR_FA_REJ_POPUP_MEMBER_DROPDOWN]'
GO

ALTER PROCEDURE [dbo].[PHAR_FA_REJ_POPUP_MEMBER_DROPDOWN] @pKey NVARCHAR(30) = ''
	,@pWeek NVARCHAR(14) = ''
	,@pDay NVARCHAR(3) = NULL
	,@pDebug TINYINT = 0
AS
BEGIN
	DECLARE @StartDate DATETIME
		,@EndDate DATETIME
		,@StartDay TINYINT
		,@DayNo TINYINT
		,@TrueStartDay TINYINT
		,@WhereCondition NVARCHAR(500)
		,@SQL NVARCHAR(max) = ''
		,@MemberID NVARCHAR(50) = ''
		,@ClaimID NVARCHAR(25) = ''

	SELECT @StartDay = CODE
	FROM dbo.SUP_SUPPORT_CODE
	WHERE CODE_TYPE = 'FA_FIRST_DAY_OF_WEEK'

	SET DATEFIRST @StartDay
	SET @ClaimID = @pKey

	--Supply default parameter value to allow proc to run and return results with no parameters specified
	IF @ClaimID IS NULL
		OR @ClaimID = ''
		SET @ClaimID = N'4'
	SET @MemberID = (
			SELECT CARD_ID
			FROM RX_CLAIMS_FA_REJ v
			INNER JOIN dbo.SUP_SUPPORT_CODE c1 ON c1.CODE = v.STATUS
				AND c1.CODE_TYPE = 'FA_REJ_STATUS'
			INNER JOIN dbo.SUP_SUPPORT_CODE c2 ON c2.CODE = v.CADRE_CODE
				AND c2.CODE_TYPE = 'FA_REJ'
			WHERE REJECTION_ID = @ClaimID
			)

	------------------------------------------------------------------------------
	--Dev only                                                                  --
	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @pWeek = '2015-05-25' --
			------------------------------------------------------------------------------

	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @StartDate = DATEADD(dd, - 7, DATEADD(dd, 1 - DATEPART(dw, GETDATE()), CONVERT(DATETIME, FLOOR(CONVERT(DECIMAL(16, 4), GETDATE())))))
	ELSE
		SET @StartDate = CAST(@pWeek AS DATETIME)

	SET @EndDate = DATEADD(dd, 6, @StartDate)

	IF @pDay IS NOT NULL
		AND @pDay <> ''
	BEGIN
		SET @DayNo = CASE 
				WHEN @pDay = 'Mon'
					THEN 1
				WHEN @pDay = 'Tue'
					THEN 2
				WHEN @pDay = 'Wed'
					THEN 3
				WHEN @pDay = 'Thu'
					THEN 4
				WHEN @pDay = 'Fri'
					THEN 5
				WHEN @pDay = 'Sat'
					THEN 6
				WHEN @pDay = 'Sun'
					THEN 7
				END
		SET @TrueStartDay = DATEPART(dw, @StartDate) + (@StartDay - 1)

		IF @DayNo >= @TrueStartDay
			SET @StartDate = DATEADD(dd, (@DayNo - @TrueStartDay), @StartDate)

		IF @DayNo < @TrueStartDay
			SET @StartDate = DATEADD(dd, 7 - (@TrueStartDay - @DayNo), @StartDate)
		SET @EndDate = @StartDate
	END

	--Debug
	SET @WhereCondition = ' WHERE CARD_ID = ''' + @MemberID + ''' AND IGNORE = 0 '
	--Updated where clause to use week and day
	SET @WhereCondition = @WhereCondition + 'AND  v.REJECTION_DATE BETWEEN ''' + CONVERT(VARCHAR(12), @StartDate, 101) + ''' AND ''' + CONVERT(VARCHAR(12), @EndDate, 101) + ''' '
	--build select statement
	SET @SQL = 
		N'SELECT     
	CASE WHEN c1.CODE = 1  THEN 
				STUFF(( SELECT '','' + CODE_DESC
				FROM dbo.SUP_SUPPORT_CODE
				WHERE CODE_TYPE = ''FA_REJ_STATUS''
				AND CODE_DESC <> ''Improper''
				ORDER BY CASE WHEN c1.CODE = 1 THEN 1
							  WHEN c1.CODE = 2 THEN 2
							  WHEN c1.CODE = 3 THEN 3
							  END
				FOR XML PATH('''')),1,1,'''') 
 
	WHEN c1.CODE  = 2 THEN 
				STUFF(( SELECT '','' + CODE_DESC
				FROM dbo.SUP_SUPPORT_CODE
				WHERE CODE_TYPE = ''FA_REJ_STATUS''
				AND CODE_DESC <> ''Improper''
				ORDER BY CASE WHEN c1.CODE = 1 THEN 3
							  WHEN c1.CODE = 2 THEN 1
							  WHEN c1.CODE = 3 THEN 2
							  END
				FOR XML PATH('''')),1,1,'''') 
	
	
	WHEN c1.CODE = 3 THEN 
				STUFF(( SELECT '','' + CODE_DESC
				FROM dbo.SUP_SUPPORT_CODE
				WHERE CODE_TYPE = ''FA_REJ_STATUS''
				AND CODE_DESC <> ''Improper''
				ORDER BY CASE WHEN c1.CODE = 1 THEN 3
							  WHEN c1.CODE = 2 THEN 2
							  WHEN c1.CODE = 3 THEN 1
							  END
				FOR XML PATH('''')),1,1,'''')
	WHEN c1.CODE = 0 THEN 
				STUFF(( SELECT '','' + CODE_DESC
				FROM dbo.SUP_SUPPORT_CODE
				WHERE CODE_TYPE = ''FA_REJ_STATUS''
				ORDER BY CASE WHEN c1.CODE = 1 THEN 1
							  WHEN c1.CODE = 2 THEN 2
							  WHEN c1.CODE = 3 THEN 3
							  WHEN c1.CODE = 0 THEN 0
							  END 
				FOR XML PATH('''')),1,1,'''')
	END
	AS ''STATUS''

FROM RX_CLAIMS_FA_REJ v

LEFT OUTER JOIN dbo.RX_NDC_DRUGS x ON x.DRUG_NDC_CODE = v.DRUG_NDC_CODE
JOIN dbo.SUP_SUPPORT_CODE c1 ON c1.CODE = v.STATUS AND c1.CODE_TYPE = ''FA_REJ_STATUS''
JOIN dbo.SUP_SUPPORT_CODE c2 ON c2.CODE = v.CADRE_CODE AND c2.CODE_TYPE = ''FA_REJ''	' 
		+ @WhereCondition + 'ORDER BY REJECTION_DATE DESC,FILL_DATE DESC,EXTERNAL_ID DESC'

	--    N'SELECT
	--        STUFF(( SELECT '','' + CODE_DESC
	--        FROM dbo.SUP_SUPPORT_CODE
	--        WHERE CODE_TYPE = ''FA_REJ_STATUS''
	--        AND CODE_DESC <> ''Improper''
	--        ORDER BY CODE_DESC
	--        FOR XML PATH('''')),1,1,'''') 
	--    FROM RX_CLAIMS_FA_REJ v
	--    LEFT OUTER JOIN dbo.RX_NDC_DRUGS x ON x.DRUG_NDC_CODE = v.DRUG_NDC_CODE
	--JOIN dbo.SUP_SUPPORT_CODE c1 ON c1.CODE = v.STATUS AND c1.CODE_TYPE = ''FA_REJ_STATUS''
	--JOIN dbo.SUP_SUPPORT_CODE c2 ON c2.CODE = v.CADRE_CODE AND c2.CODE_TYPE = ''FA_REJ''	'
	-- + @WhereCondition  
	PRINT @SQL

	EXEC sp_executesql @SQL
END
GO

IF @@ERROR <> 0
	AND @@TRANCOUNT > 0
	ROLLBACK TRANSACTION
GO

IF @@TRANCOUNT = 0
BEGIN
	INSERT INTO #tmpErrors (Error)
	SELECT 1

	BEGIN TRANSACTION
END
GO

PRINT N'Altering [dbo].[PHAR_FA_REJ_POPUP_MEMBER_HEAD]'
GO

ALTER PROCEDURE [dbo].[PHAR_FA_REJ_POPUP_MEMBER_HEAD] @pKey NVARCHAR(30) = ''
	,@pWeek NVARCHAR(14) = ''
	,@pDay NVARCHAR(3) = NULL
AS
BEGIN
	DECLARE @StartDate DATETIME
		,@EndDate DATETIME
		,@StartDay TINYINT
		,@DayNo TINYINT
		,@TrueStartDay TINYINT
		,@WhereCondition NVARCHAR(500)
		,@SQL NVARCHAR(max) = ''
		,@MemberID NVARCHAR(50) = ''
		,@ClaimID NVARCHAR(25) = ''

	SELECT @StartDay = CODE
	FROM dbo.SUP_SUPPORT_CODE
	WHERE CODE_TYPE = 'FA_FIRST_DAY_OF_WEEK'

	SET DATEFIRST @StartDay
	SET @ClaimID = @pKey

	--Supply default parameter value to allow proc to run and return results with no parameters specified
	IF @ClaimID IS NULL
		OR @ClaimID = ''
		SET @ClaimID = N'4'
	SET @MemberID = (
			SELECT CARD_ID
			FROM RX_CLAIMS_FA_REJ v
			INNER JOIN dbo.SUP_SUPPORT_CODE c1 ON c1.CODE = v.STATUS
				AND c1.CODE_TYPE = 'FA_REJ_STATUS'
			INNER JOIN dbo.SUP_SUPPORT_CODE c2 ON c2.CODE = v.CADRE_CODE
				AND c2.CODE_TYPE = 'FA_REJ'
			WHERE REJECTION_ID = @ClaimID
			)

	------------------------------------------------------------------------------
	--Dev only                                                                  --
	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @pWeek = '2015-05-25' --
			------------------------------------------------------------------------------

	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @StartDate = DATEADD(dd, - 7, DATEADD(dd, 1 - DATEPART(dw, GETDATE()), CONVERT(DATETIME, FLOOR(CONVERT(DECIMAL(16, 4), GETDATE())))))
	ELSE
		SET @StartDate = CAST(@pWeek AS DATETIME)

	SET @EndDate = DATEADD(dd, 6, @StartDate)

	IF @pDay IS NOT NULL
		AND @pDay <> ''
	BEGIN
		SET @DayNo = CASE 
				WHEN @pDay = 'Mon'
					THEN 1
				WHEN @pDay = 'Tue'
					THEN 2
				WHEN @pDay = 'Wed'
					THEN 3
				WHEN @pDay = 'Thu'
					THEN 4
				WHEN @pDay = 'Fri'
					THEN 5
				WHEN @pDay = 'Sat'
					THEN 6
				WHEN @pDay = 'Sun'
					THEN 7
				END
		SET @TrueStartDay = DATEPART(dw, @StartDate) + (@StartDay - 1)

		IF @DayNo >= @TrueStartDay
			SET @StartDate = DATEADD(dd, (@DayNo - @TrueStartDay), @StartDate)

		IF @DayNo < @TrueStartDay
			SET @StartDate = DATEADD(dd, 7 - (@TrueStartDay - @DayNo), @StartDate)
		SET @EndDate = @StartDate
	END

	SET @WhereCondition = ' WHERE CARD_ID = ''' + @MemberID + ''' AND IGNORE = 0 '
	--Updated where clause to use week and day
	SET @WhereCondition = @WhereCondition + 'AND  v.REJECTION_DATE BETWEEN ''' + CONVERT(VARCHAR(12), @StartDate, 101) + ''' AND ''' + CONVERT(VARCHAR(12), @EndDate, 101) + ''' '
	--build select statement
	SET @SQL = N'SELECT  
		''=##==#'' + c2.CODE_TYPE_DESC+ ''#='' + ''=#''+v.REJ_DETAIL +''#==#''+c2.CODE_SUMMARY+ ''#==#Claim ID: ''+EXTERNAL_ID+''#='' AS TITLE, c2.CODE_TYPE_DESC as COLOR_PICKER
FROM RX_CLAIMS_FA_REJ v

LEFT OUTER JOIN dbo.RX_NDC_DRUGS x ON x.DRUG_NDC_CODE = v.DRUG_NDC_CODE
JOIN dbo.SUP_SUPPORT_CODE c1 ON c1.CODE = v.STATUS AND c1.CODE_TYPE = ''FA_REJ_STATUS''
JOIN dbo.SUP_SUPPORT_CODE c2 ON c2.CODE = v.CADRE_CODE AND c2.CODE_TYPE = ''FA_REJ''	' + @WhereCondition + 'ORDER BY REJECTION_DATE DESC,FILL_DATE DESC,EXTERNAL_ID DESC'

	PRINT @SQL

	EXEC sp_executesql @SQL
END
GO

IF @@ERROR <> 0
	AND @@TRANCOUNT > 0
	ROLLBACK TRANSACTION
GO

IF @@TRANCOUNT = 0
BEGIN
	INSERT INTO #tmpErrors (Error)
	SELECT 1

	BEGIN TRANSACTION
END
GO

PRINT N'Altering [dbo].[PHAR_FA_REJ_POPUP_MEMBER_NOTES]'
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- Build by PJ
-- =============================================
ALTER PROCEDURE [dbo].[PHAR_FA_REJ_POPUP_MEMBER_NOTES] @pKey NVARCHAR(30) = ''
	,@pWeek NVARCHAR(14) = ''
	,@pDay NVARCHAR(3) = NULL
	,@pSQL NVARCHAR(max) = '' -- OUTPUT
AS
BEGIN
	DECLARE @StartDate DATETIME
		,@EndDate DATETIME
		,@StartDay TINYINT
		,@DayNo TINYINT
		,@TrueStartDay TINYINT
		,@WhereCondition NVARCHAR(500)
		,@SQL NVARCHAR(max) = ''
		,@MemberID NVARCHAR(50) = ''
		,@ClaimID NVARCHAR(25) = ''

	SELECT @StartDay = CODE
	FROM dbo.SUP_SUPPORT_CODE
	WHERE CODE_TYPE = 'FA_FIRST_DAY_OF_WEEK'

	SET DATEFIRST @StartDay
	SET @ClaimID = @pKey

	--Supply default parameter value to allow proc to run and return results with no parameters specified
	IF @ClaimID IS NULL
		OR @ClaimID = ''
		SET @ClaimID = N'96441'
	SET @MemberID = (
			SELECT CARD_ID
			FROM RX_CLAIMS_FA_REJ v
			INNER JOIN dbo.SUP_SUPPORT_CODE c1 ON c1.CODE = v.STATUS
				AND c1.CODE_TYPE = 'FA_REJ_STATUS'
			INNER JOIN dbo.SUP_SUPPORT_CODE c2 ON c2.CODE = v.CADRE_CODE
				AND c2.CODE_TYPE = 'FA_REJ'
			WHERE REJECTION_ID = @ClaimID
			)

	------------------------------------------------------------------------------
	--Dev only                                                                  --
	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @pWeek = '2015-01-25' --
			------------------------------------------------------------------------------

	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @StartDate = DATEADD(dd, - 7, DATEADD(dd, 1 - DATEPART(dw, GETDATE()), CONVERT(DATETIME, FLOOR(CONVERT(DECIMAL(16, 4), GETDATE())))))
	ELSE
		SET @StartDate = CAST(@pWeek AS DATETIME)

	SET @EndDate = DATEADD(dd, 6, @StartDate)

	IF @pDay IS NOT NULL
		AND @pDay <> ''
	BEGIN
		SET @DayNo = CASE 
				WHEN @pDay = 'Mon'
					THEN 1
				WHEN @pDay = 'Tue'
					THEN 2
				WHEN @pDay = 'Wed'
					THEN 3
				WHEN @pDay = 'Thu'
					THEN 4
				WHEN @pDay = 'Fri'
					THEN 5
				WHEN @pDay = 'Sat'
					THEN 6
				WHEN @pDay = 'Sun'
					THEN 7
				END
		SET @TrueStartDay = DATEPART(dw, @StartDate) + (@StartDay - 1)

		IF @DayNo >= @TrueStartDay
			SET @StartDate = DATEADD(dd, (@DayNo - @TrueStartDay), @StartDate)

		IF @DayNo < @TrueStartDay
			SET @StartDate = DATEADD(dd, 7 - (@TrueStartDay - @DayNo), @StartDate)
		SET @EndDate = @StartDate
	END

	SET @WhereCondition = ' WHERE CARD_ID = ''' + @MemberID + ''' AND IGNORE = 0 '

	--I wanted to make this easily eitable, so i built two temporary tables to format notes into a single variable
	--rather than putting a nested query into the select statement
	--in the first query, we gather all notes for a member,
	--in the second query, we concate the notes into a single string
	CREATE TABLE #tempNotes (
		CLAIM_ID BIGINT
		,[DATE] DATETIME
		,[KEY] NVARCHAR(max)
		)

	--select notes, update temp table
	SET @pSQL = 'SELECT CLAM_ID,UPDATE_STATUS_DATE,
  ''=#''+cast(UPDATE_STATUS_DATE AS NVARCHAR)+''#=''+''=#by ''+cast(UPDATE_STATUS_PERSON AS NVARCHAR)+''#=''+''=#''+CAST(NOTES AS NVARCHAR(MAX)) +''#='' AS [KEY] 
 	FROM FA_REJ_NOTES
	WHERE MEMBER_ID = ''' + @MemberID + '''
	ORDER BY UPDATE_STATUS_DATE'

	PRINT @pSQL

	INSERT INTO #tempNotes
	EXEC sp_executesql @pSQL

	--second formated table
	CREATE TABLE #formatedTemp (
		CLAIM_ID BIGINT
		,[KEY] NVARCHAR(max)
		)

	--query puts notes in a single string from the previous table
	SET @pSQL = ' Select distinct ST2.CLAIM_ID,
    substring(
        (
            Select '',''+ST1.[KEY]  AS [text()]
            From dbo.#tempNotes ST1
            Where ST1.CLAIM_ID  = ST2.CLAIM_ID 
            ORDER BY ST1.CLAIM_ID,ST1.DATE 
            For XML PATH ('''')' +
		--SubString is activated, 2,10000
		'        ), 2, 10000) [#tempNotes]
From dbo.#tempNotes ST2'

	INSERT INTO #formatedTemp
	EXEC sp_executesql @pSQL

	PRINT @pSQL

	--build select statement
	SET @WhereCondition = ' WHERE  CARD_ID = ''' + @MemberID + ''''
	--Updated where clause to use week and day
	SET @WhereCondition = @WhereCondition + 'AND  v.REJECTION_DATE BETWEEN ''' + CONVERT(VARCHAR(12), @StartDate, 101) + ''' AND ''' + CONVERT(VARCHAR(12), @EndDate, 101) + ''' AND IGNORE = 0'

	PRINT @WhereCondition

	SET @SQL = N'SELECT  REJECTION_ID AS CLAM_ID,
[KEY] AS NOTES 
FROM RX_CLAIMS_FA_REJ v
JOIN dbo.SUP_SUPPORT_CODE c2 ON c2.CODE = v.CADRE_CODE AND c2.CODE_TYPE = ''FA_REJ''
JOIN dbo.SUP_SUPPORT_CODE c1 ON c1.CODE = v.STATUS AND c1.CODE_TYPE = ''FA_REJ_STATUS''
LEFT JOIN #formatedTemp NOTES ON REJECTION_ID = NOTES.CLAIM_ID' + @WhereCondition + 'ORDER BY REJECTION_DATE DESC,FILL_DATE DESC,EXTERNAL_ID DESC'

	--+' ORDER BY NOTES.UPDATE_STATUS_DATE'
	PRINT @SQL

	EXEC sp_executesql @SQL

	DROP TABLE #formatedTemp

	DROP TABLE #tempNotes
END
GO

IF @@ERROR <> 0
	AND @@TRANCOUNT > 0
	ROLLBACK TRANSACTION
GO

IF @@TRANCOUNT = 0
BEGIN
	INSERT INTO #tmpErrors (Error)
	SELECT 1

	BEGIN TRANSACTION
END
GO

PRINT N'Altering [dbo].[PHAR_FA_REJ_SUMMARY_TABLE]'
GO

ALTER PROCEDURE [dbo].[PHAR_FA_REJ_SUMMARY_TABLE] @pWeek NVARCHAR(12) = NULL
AS
BEGIN
	DECLARE @COB VARCHAR(50)
		,@MemberID VARCHAR(50)
		,@Misc VARCHAR(50)
		,@Pharmacy VARCHAR(50)
		,@Prescriber VARCHAR(50)
		,@ProtectedClass VARCHAR(50)
		,@PriorAuthorization VARCHAR(50)
		,@StepTherapy VARCHAR(50)
		,@QuantityLimit VARCHAR(50)
		,@Nonformulary VARCHAR(50)
		,@RefillTooSoon VARCHAR(50)
		,@RxCost VARCHAR(50)
		,@RxDuration VARCHAR(50)
		,@StartDay TINYINT
		,@StartDate DATETIME
		,@EndDate DATETIME
		,@SQL NVARCHAR(MAX)

	SELECT @StartDay = CODE
	FROM dbo.SUP_SUPPORT_CODE
	WHERE CODE_TYPE = 'FA_FIRST_DAY_OF_WEEK'

	SET DATEFIRST @StartDay

	------------------------------------------------------------------------------
	--Dev only                                                                  --
	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @pWeek = '2015-05-25' --
			------------------------------------------------------------------------------ 

	IF @pWeek IS NULL
		OR @pWeek = ''
		SET @StartDate = DATEADD(dd, - 7, DATEADD(dd, 1 - DATEPART(dw, GETDATE()), CONVERT(DATETIME, FLOOR(CONVERT(DECIMAL(16, 4), GETDATE())))))
	ELSE
		SET @StartDate = CAST(@pWeek AS DATETIME)

	SET @EndDate = DATEADD(dd, 6, @StartDate)
	SET @COB = 'c2.CODE = ''COB'' '
	SET @MemberID = 'c2.CODE = ''MEMBER_ID'' '
	SET @Misc = 'c2.CODE = ''MISC'' '
	SET @Pharmacy = 'c2.CODE = ''PHARMACY'' '
	SET @Prescriber = 'c2.CODE = ''PRESCRIBER'' '
	SET @ProtectedClass = 'c2.CODE = ''Protected Class'' '
	SET @PriorAuthorization = 'c2.CODE = ''PA'' '
	SET @StepTherapy = 'c2.CODE = ''ST'' '
	SET @QuantityLimit = 'c2.CODE = ''QL'' '
	SET @Nonformulary = 'c2.CODE = ''Non-FORMULARY'' '
	SET @RefillTooSoon = 'c2.CODE = ''RFTS'' '
	SET @RxCost = 'c2.CODE = ''Rx COST'' '
	SET @RxDuration = 'c2.CODE = ''Rx DURATION'' '
	SET @SQL = N'SELECT

	SUM(CASE WHEN ' + @COB + ' AND OUTLIER = 0 THEN 1 ELSE 0 END) AS COB_PROPER_COUNT
    ,SUM(CASE WHEN ' + @COB + ' AND OUTLIER = 1 THEN 1 ELSE 0 END) AS COB_IMPROPER_COUNT
	,SUM(CASE WHEN ' + @COB + ' AND c1.CODE = ''1'' THEN 1 ELSE 0 END) AS COB_OPEN_COUNT
	,SUM(CASE WHEN ' + @COB + ' AND c1.CODE = ''2'' THEN 1 ELSE 0 END) AS COB_PENDING_COUNT
	,SUM(CASE WHEN ' + @COB + ' AND c1.CODE = ''3'' THEN 1 ELSE 0 END) AS COB_RESOLVED_COUNT '
	SET @SQL = @SQL + N',SUM(CASE WHEN ' + @MemberID + ' AND OUTLIER = 0 THEN 1 ELSE 0 END) AS MEMBER_ID_PROPER_COUNT
    ,SUM(CASE WHEN ' + @MemberID + ' AND OUTLIER = 1 THEN 1 ELSE 0 END) AS MEMBER_ID_IMPROPER_COUNT
	,SUM(CASE WHEN ' + @MemberID + ' AND c1.CODE = ''1'' THEN 1 ELSE 0 END) AS MEMBER_ID_OPEN_COUNT
	,SUM(CASE WHEN ' + @MemberID + ' AND c1.CODE = ''2'' THEN 1 ELSE 0 END) AS MEMBER_ID_PENDING_COUNT
	,SUM(CASE WHEN ' + @MemberID + ' AND c1.CODE = ''3'' THEN 1 ELSE 0 END) AS MEMBER_ID_RESOLVED_COUNT '
	SET @SQL = @SQL + N',SUM(CASE WHEN ' + @Misc + ' AND OUTLIER = 0 THEN 1 ELSE 0 END) AS MISC_PROPER_COUNT
    ,SUM(CASE WHEN ' + @Misc + ' AND OUTLIER = 1 THEN 1 ELSE 0 END) AS MISC_IMPROPER_COUNT
	,SUM(CASE WHEN ' + @Misc + ' AND c1.CODE = ''1'' THEN 1 ELSE 0 END) AS MISC_OPEN_COUNT
	,SUM(CASE WHEN ' + @Misc + ' AND c1.CODE = ''2'' THEN 1 ELSE 0 END) AS MISC_PENDING_COUNT
	,SUM(CASE WHEN ' + @Misc + ' AND c1.CODE = ''3'' THEN 1 ELSE 0 END) AS MISC_RESOLVED_COUNT '
	SET @SQL = @SQL + N',SUM(CASE WHEN ' + @Pharmacy + ' AND OUTLIER = 0 THEN 1 ELSE 0 END) AS PHARMACY_PROPER_COUNT
    ,SUM(CASE WHEN ' + @Pharmacy + ' AND OUTLIER = 1 THEN 1 ELSE 0 END) AS PHARMACY_IMPROPER_COUNT
	,SUM(CASE WHEN ' + @Pharmacy + ' AND c1.CODE = ''1'' THEN 1 ELSE 0 END) AS PHARMACY_OPEN_COUNT
	,SUM(CASE WHEN ' + @Pharmacy + ' AND c1.CODE = ''2'' THEN 1 ELSE 0 END) AS PHARMACY_PENDING_COUNT
	,SUM(CASE WHEN ' + @Pharmacy + ' AND c1.CODE = ''3'' THEN 1 ELSE 0 END) AS PHARMACY_RESOLVED_COUNT '
	SET @SQL = @SQL + N',SUM(CASE WHEN ' + @Prescriber + ' AND OUTLIER = 0 THEN 1 ELSE 0 END) AS PRESCRIBER_PROPER_COUNT
    ,SUM(CASE WHEN ' + @Prescriber + ' AND OUTLIER = 1 THEN 1 ELSE 0 END) AS PRESCRIBER_IMPROPER_COUNT
	,SUM(CASE WHEN ' + @Prescriber + ' AND c1.CODE = ''1'' THEN 1 ELSE 0 END) AS PRESCRIBER_OPEN_COUNT
	,SUM(CASE WHEN ' + @Prescriber + ' AND c1.CODE = ''2'' THEN 1 ELSE 0 END) AS PRESCRIBER_PENDING_COUNT
	,SUM(CASE WHEN ' + @Prescriber + ' AND c1.CODE = ''3'' THEN 1 ELSE 0 END) AS PRESCRIBER_RESOLVED_COUNT '
	SET @SQL = @SQL + N',SUM(CASE WHEN ' + @ProtectedClass + ' AND OUTLIER = 0 THEN 1 ELSE 0 END) AS PROTECTED_CLASS_PROPER_COUNT
    ,SUM(CASE WHEN ' + @ProtectedClass + ' AND OUTLIER = 1 THEN 1 ELSE 0 END) AS PROTECTED_CLASS_IMPROPER_COUNT
	,SUM(CASE WHEN ' + @ProtectedClass + ' AND c1.CODE = ''1'' THEN 1 ELSE 0 END) AS PROTECTED_CLASS_OPEN_COUNT
	,SUM(CASE WHEN ' + @ProtectedClass + ' AND c1.CODE = ''2'' THEN 1 ELSE 0 END) AS PROTECTED_CLASS_PENDING_COUNT
	,SUM(CASE WHEN ' + @ProtectedClass + ' AND c1.CODE = ''3'' THEN 1 ELSE 0 END) AS PROTECTED_CLASS_RESOLVED_COUNT '
	SET @SQL = @SQL + N',SUM(CASE WHEN ' + @PriorAuthorization + ' AND OUTLIER = 0 THEN 1 ELSE 0 END) AS PRIOR_AUTH_PROPER_COUNT
    ,SUM(CASE WHEN ' + @PriorAuthorization + ' AND OUTLIER = 1 THEN 1 ELSE 0 END) AS PRIOR_AUTH_IMPROPER_COUNT
	,SUM(CASE WHEN ' + @PriorAuthorization + ' AND c1.CODE = ''1'' THEN 1 ELSE 0 END) AS PRIOR_AUTH_OPEN_COUNT
	,SUM(CASE WHEN ' + @PriorAuthorization + ' AND c1.CODE = ''2'' THEN 1 ELSE 0 END) AS PRIOR_AUTH_PENDING_COUNT
	,SUM(CASE WHEN ' + @PriorAuthorization + ' AND c1.CODE = ''3'' THEN 1 ELSE 0 END) AS PRIOR_AUTH_RESOLVED_COUNT '
	SET @SQL = @SQL + N',SUM(CASE WHEN ' + @StepTherapy + ' AND OUTLIER = 0 THEN 1 ELSE 0 END) AS STEP_THERAPY_PROPER_COUNT
    ,SUM(CASE WHEN ' + @StepTherapy + ' AND OUTLIER = 1 THEN 1 ELSE 0 END) AS STEP_THERAPY_IMPROPER_COUNT
	,SUM(CASE WHEN ' + @StepTherapy + ' AND c1.CODE = ''1'' THEN 1 ELSE 0 END) AS STEP_THERAPY_OPEN_COUNT
	,SUM(CASE WHEN ' + @StepTherapy + ' AND c1.CODE = ''2'' THEN 1 ELSE 0 END) AS STEP_THERAPY_PENDING_COUNT
	,SUM(CASE WHEN ' + @StepTherapy + ' AND c1.CODE = ''3'' THEN 1 ELSE 0 END) AS STEP_THERAPY_RESOLVED_COUNT '
	SET @SQL = @SQL + N',SUM(CASE WHEN ' + @QuantityLimit + ' AND OUTLIER = 0 THEN 1 ELSE 0 END) AS QUANTITY_LIMIT_PROPER_COUNT
    ,SUM(CASE WHEN ' + @QuantityLimit + ' AND OUTLIER = 1 THEN 1 ELSE 0 END) AS QUANTITY_LIMIT_IMPROPER_COUNT
	,SUM(CASE WHEN ' + @QuantityLimit + ' AND c1.CODE = ''1'' THEN 1 ELSE 0 END) AS QUANTITY_LIMIT_OPEN_COUNT
	,SUM(CASE WHEN ' + @QuantityLimit + ' AND c1.CODE = ''2'' THEN 1 ELSE 0 END) AS QUANTITY_LIMIT_PENDING_COUNT
	,SUM(CASE WHEN ' + @QuantityLimit + ' AND c1.CODE = ''3'' THEN 1 ELSE 0 END) AS QUANTITY_LIMIT_RESOLVED_COUNT '
	SET @SQL = @SQL + N',SUM(CASE WHEN ' + @Nonformulary + ' AND OUTLIER = 0 THEN 1 ELSE 0 END) AS NONFORMULARY_PROPER_COUNT
    ,SUM(CASE WHEN ' + @Nonformulary + ' AND OUTLIER = 1 THEN 1 ELSE 0 END) AS NONFORMULARY_IMPROPER_COUNT
	,SUM(CASE WHEN ' + @Nonformulary + ' AND c1.CODE = ''1'' THEN 1 ELSE 0 END) AS NONFORMULARY_OPEN_COUNT
	,SUM(CASE WHEN ' + @Nonformulary + ' AND c1.CODE = ''2'' THEN 1 ELSE 0 END) AS NONFORMULARY_PENDING_COUNT
	,SUM(CASE WHEN ' + @Nonformulary + ' AND c1.CODE = ''3'' THEN 1 ELSE 0 END) AS NONFORMULARY_RESOLVED_COUNT '
	SET @SQL = @SQL + N',SUM(CASE WHEN ' + @RefillTooSoon + ' AND OUTLIER = 0 THEN 1 ELSE 0 END) AS REFILL_TOO_SOON_PROPER_COUNT
    ,SUM(CASE WHEN ' + @RefillTooSoon + ' AND OUTLIER = 1 THEN 1 ELSE 0 END) AS REFILL_TOO_SOON_IMPROPER_COUNT
	,SUM(CASE WHEN ' + @RefillTooSoon + ' AND c1.CODE = ''1'' THEN 1 ELSE 0 END) AS REFILL_TOO_SOON_OPEN_COUNT
	,SUM(CASE WHEN ' + @RefillTooSoon + ' AND c1.CODE = ''2'' THEN 1 ELSE 0 END) AS REFILL_TOO_SOON_PENDING_COUNT
	,SUM(CASE WHEN ' + @RefillTooSoon + ' AND c1.CODE = ''3'' THEN 1 ELSE 0 END) AS REFILL_TOO_SOON_RESOLVED_COUNT '
	SET @SQL = @SQL + N',SUM(CASE WHEN ' + @RxCost + ' AND OUTLIER = 0 THEN 1 ELSE 0 END) AS RX_COST_PROPER_COUNT
    ,SUM(CASE WHEN ' + @RxCost + ' AND OUTLIER = 1 THEN 1 ELSE 0 END) AS RX_COST_IMPROPER_COUNT
	,SUM(CASE WHEN ' + @RxCost + ' AND c1.CODE = ''1'' THEN 1 ELSE 0 END) AS RX_COST_OPEN_COUNT
	,SUM(CASE WHEN ' + @RxCost + ' AND c1.CODE = ''2'' THEN 1 ELSE 0 END) AS RX_COST_PENDING_COUNT
	,SUM(CASE WHEN ' + @RxCost + ' AND c1.CODE = ''3'' THEN 1 ELSE 0 END) AS RX_COST_RESOLVED_COUNT '
	SET @SQL = @SQL + N',SUM(CASE WHEN ' + @RxDuration + ' AND OUTLIER = 0 THEN 1 ELSE 0 END) AS RX_DURATION_PROPER_COUNT
    ,SUM(CASE WHEN ' + @RxDuration + ' AND OUTLIER = 1 THEN 1 ELSE 0 END) AS RX_DURATION_IMPROPER_COUNT
	,SUM(CASE WHEN ' + @RxDuration + ' AND c1.CODE = ''1'' THEN 1 ELSE 0 END) AS RX_DURATION_OPEN_COUNT
	,SUM(CASE WHEN ' + @RxDuration + ' AND c1.CODE = ''2'' THEN 1 ELSE 0 END) AS RX_DURATION_PENDING_COUNT
	,SUM(CASE WHEN ' + @RxDuration + ' AND c1.CODE = ''3'' THEN 1 ELSE 0 END) AS RX_DURATION_RESOLVED_COUNT
    '
	SET @SQL = @SQL + N'FROM dbo.RX_CLAIMS_FA_REJ r 
	JOIN dbo.SUP_SUPPORT_CODE c1 ON c1.CODE = r.[STATUS] AND c1.CODE_TYPE = ''FA_REJ_STATUS''
	--JOIN dbo.SUP_SUPPORT_CODE c2 ON c2.CODE = r.CADRE_CODE AND c2.CODE_TYPE = ''FA_REJ''
    JOIN dbo.PHAR_FA_REJECTION_CODE c2 ON c2.CODE_DESC = r.CADRE_CODE 
	WHERE r.CLAIM_ACCEPTED = 0 
    AND r.IGNORE = 0
	AND r.REJECTION_DATE BETWEEN ''' + CONVERT(VARCHAR(12), @StartDate, 101) + ''' AND ''' + CONVERT(VARCHAR(12), @EndDate, 101) + ''' 
	'

	PRINT CAST(@SQL AS TEXT)

	EXEC sp_executesql @SQL
END
GO



