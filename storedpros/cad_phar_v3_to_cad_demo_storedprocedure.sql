use cad_demo
go
ALTER PROCEDURE [dbo].[PDE_REC_CLAIM_DETAILS] (
	@pKey VARCHAR(50) = ''
	,@pPdeStatus VARCHAR(10) = ''
	,@pProductID NVARCHAR(10) = NULL
	,@pMonth NVARCHAR(2) = ''
	,@pFirstErrorOnly VARCHAR(1) = ''
	,@pSQL NVARCHAR(max) = '' OUTPUT
	)
AS
BEGIN
	DECLARE @pWhereCondition NVARCHAR(max) = ''
		,@pFromStatement NVARCHAR(max) = ''
		,@JoinParameter NVARCHAR(1000) = ''
		,@PbmID NVARCHAR(50) = ''
		,@ClaimID NVARCHAR(50) = ''

	SET @ClaimID = @pKey

	--SET DEFAULT PARAMETERS
	IF @ClaimID IS NULL
		OR @ClaimID = ''
		SET @ClaimID = '1826937'

	SELECT @PbmID = (
			SELECT CLAM_CHECK_REFERENCE_NUMBER
			FROM RX_CLAIMS
			WHERE CLAM_ID = @ClaimID
			)

	SET @pWhereCondition = 'A.CLAIM_ID = ''' + @ClaimID + ''' AND DRUG_COVERAGE_STATUS_CODE IN (''C'',''E'',''O'')'
	SET @pFromStatement = CASE 
			WHEN upper(@pFirstErrorOnly) = 'Y'
				THEN 'FROM dbo.RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA A
		JOIN RX_CLAIMS B ON A.CLAIM_ID = B.CLAM_ID --AND A.PDE_SEQ = B.PDE_SEQ
		LEFT join RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA_GAP C ON A.CLAIM_ID = C.CLAM_ID AND A.PDE_SEQ = C.PDE_SEQ
		JOIN MB_ENROLLEE_INFO D ON B.RX_MEME_ID = D.MEMBER_ID
		LEFT JOIN RX_NDC_DRUGS E ON B.DRUG_NDC_CODE = E.DRUG_NDC_CODE
		JOIN dbo.RX_CMS_PDED_DETAIL_ERROR_CODE PDEDD ON A.CLAIM_ID=PDEDD.CLAIM_ID AND A.ERROR_SUBMISSION_NUM = PDEDD.ERROR_SUBMISSION_NUM AND SUBSTRING(A.ERROR_CODE,1,3) = PDEDD.ERROR_CODE
		JOIN dbo.PDE_REJECT_CODE PDER on PDEDD.ERROR_CODE = PDER.ERROR_CODE'
			ELSE 'FROM dbo.RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA A
		INNER JOIN RX_CLAIMS B ON A.CLAIM_ID = B.CLAM_ID --AND A.PDE_SEQ = B.PDE_SEQ 
		LEFT join RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA_GAP C ON A.CLAIM_ID = C.CLAM_ID AND A.PDE_SEQ = C.PDE_SEQ
		JOIN MB_ENROLLEE_INFO D ON B.RX_MEME_ID = D.MEMBER_ID
		LEFT JOIN RX_NDC_DRUGS E ON B.DRUG_NDC_CODE = E.DRUG_NDC_CODE
		INNER JOIN dbo.RX_CMS_PDED_DETAIL_ERROR_CODE PDEDD ON A.CLAIM_ID=PDEDD.CLAIM_ID
		INNER JOIN dbo.PDE_REJECT_CODE PDER ON PDEDD.ERROR_CODE = PDER.ERROR_CODE AND A.ERROR_SUBMISSION_NUM = PDEDD.ERROR_SUBMISSION_NUM'
			END
	--Set columns for select statement
	SET @pSQL = 
		'SELECT B.RX_MEME_ID AS MEMBER_ID,
			MEMBER_NAME,
		    RIGHT(CSPI_ID,1) as [LICS_TIER],
			CASE WHEN BSDL_MCTR_TYPE = 0 THEN CLAM_DRUG_TYPE ELSE BSDL_MCTR_TYPE END as [DRUG_TIER],
			B.CLAM_ID,
			CLAM_CHECK_REFERENCE_NUMBER AS [PBM_ID], 
			E.DRUG_NDC_CODE as DRUG_NDC,
			CLAM_ORIGINAL_ENTRY_DATE AS PAID_DT,
		   (CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (INGREDIENT_COST_PAID+DISPENSING_FEE_PAID)  
			ELSE  (0 - (INGREDIENT_COST_PAID+DISPENSING_FEE_PAID)) END) AS [COST],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (A.PATIENT_PAY_AMOUNT)  
			ELSE  (0 - (A.PATIENT_PAY_AMOUNT)) END) AS [COPAY],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (A.LICS)  
			ELSE  (0 - (A.LICS)) END) AS [LICS],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (GDCB)  
			ELSE  (0 - (GDCB)) END) AS [GDCB],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (A.CPP)  
			ELSE  (0 - (A.CPP)) END) AS [CPP],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (PLRO)  
			ELSE  (0 - (PLRO)) END) AS [PLRO],
			E.DRUG_NAME,
			FILL_DT,
			COST_ACCU AS TGCDCA,
			TROOP_ACCU AS TROOPA,
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (CGDP)  
			ELSE  (0 - (CGDP)) END) AS [CGDP],
			(GDCA)  AS [GDCA],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (A.NPP)  
			ELSE  (0 - (A.NPP)) END) AS [NPP],'
	SET @pSQL = @pSQL + '
			(P_LEVEL_P1)  AS [COPAY_DEDUCT],
			(P_LEVEL_P2)  AS [COPAY_COV],
			(P_LEVEL_P3)  AS [COPAY_GAP],
			(P_LEVEL_P4)  AS [COPAY_CAT],
			(P_LEVEL1) AS [COST_DEDUCT],
			(P_LEVEL2) AS [COST_COV],
			(P_LEVEL3) AS [COST_GAP],
			(P_LEVEL4) AS [COST_CAT],
			(P_LEVEL_P1+P_LEVEL_P2+P_LEVEL_P3+P_LEVEL_P4) AS [COPAY_TOT],
			(P_LEVEL1+P_LEVEL2+P_LEVEL3+P_LEVEL4) AS [COST_TOTAL],
			(C.LICS) AS PBM_LICS,
			''0.00'' AS LICS_FAKE'

	IF @pPdeStatus = 'REJ'
	BEGIN
		SET @pSQL = @pSQL + ',PDER.ERROR_CODE, EDITES
		' + @pFromStatement + '
		JOIN SUP_SUPPORT_CODE AGING ON CODE_TYPE=''DAY_RANGE'' AND DATEDIFF(DAY,BATCH_DATE,GETDATE()) BETWEEN CAST(CODE AS INT) AND CAST(CODE_DESC AS INT)
		LEFT JOIN MB_MEMBER_ELIGIBILITY ELIG ON B.MEMBER_CK = ELIG.MEMBER_CK AND B.CLAM_FILL_DATE BETWEEN EFFECTIVE_DATE AND TERMINATION_DATE
		WHERE ' + @pWhereCondition + '
			order by CLAM_ORIGINAL_ENTRY_DATE'

		--create temporary table to store results of pop up (ERROR CODES AND EDITES)
		---used to seperate formatting of text (<br><br\>) and select query
		CREATE TABLE #temp (
			MEMBER_ID NVARCHAR(100)
			,MEMBER_NAME NVARCHAR(100)
			,LICS_TIER NVARCHAR(10)
			,DRUG_TIER NVARCHAR(10)
			,CLAM_ID NVARCHAR(25)
			,PBM_ID NVARCHAR(100)
			,DRUG_NDC NVARCHAR(100)
			,PAID_DT DATE
			,COST MONEY
			,COPAY MONEY
			,LICS MONEY
			,GDCB MONEY
			,CPP MONEY
			,PLRO MONEY
			,DRUG_NAME NVARCHAR(100)
			,FILL_DT DATE
			,TGCDCA MONEY
			,TROOPA MONEY
			,CGDP MONEY
			,GDCA MONEY
			,NPP MONEY
			,COPAY_DEDUCT MONEY
			,COPAY_COV MONEY
			,COPAY_GAP MONEY
			,COPAY_CAT MONEY
			,COST_DEDUCT MONEY
			,COST_COV MONEY
			,COST_GAP MONEY
			,COST_CAT MONEY
			,COPAY_TOT MONEY
			,COST_TOTAL MONEY
			,PBM_LICS MONEY
			,FAKE_LICS MONEY
			,ERROR_CODE NVARCHAR(100)
			,EDITES NVARCHAR(max)
			)

		--insert data into the temporary table
		INSERT INTO #temp
		EXEC sp_executesql @pSQL

		--reformat the REJ codes as 676-766 
		SELECT DISTINCT MEMBER_ID
			,MEMBER_NAME
			,LICS_TIER
			,DRUG_TIER
			,CLAM_ID
			,PBM_ID
			,DRUG_NDC
			,PAID_DT
			,COST
			,COPAY
			,LICS
			,GDCB
			,CPP
			,PLRO
			,DRUG_NAME
			,FILL_DT
			,TGCDCA
			,TROOPA
			,CGDP
			,GDCA
			,NPP
			,COPAY_DEDUCT
			,COPAY_COV
			,COPAY_GAP
			,COPAY_CAT
			,COST_DEDUCT
			,COST_COV
			,COST_GAP
			,COST_CAT
			,COPAY_TOT
			,COST_TOTAL
			,PBM_LICS
			,FAKE_LICS
			,
			--creates a - delimited list for each claim
			STUFF((
					SELECT '-' + A.[ERROR_CODE]
					FROM #temp A
					WHERE A.[PBM_ID] = B.[PBM_ID]
					FOR XML PATH('')
					), 1, 1, '') AS [ERROR_CODE]
			,
			--creates a ',' delimited list for error descriptions
			--stuff will create an extra ',' at the begining of the string, substring removes this
			STUFF((
					SELECT ', ' + A.[EDITES]
					FROM #temp A
					WHERE A.[PBM_ID] = B.[PBM_ID]
					FOR XML PATH('')
					), 1, 1, '') AS [EDITES]
		FROM #temp B

		PRINT @pSQL
	END
	ELSE
	BEGIN
		SET @pSQL = @pSQL + '
				FROM dbo.RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA A
			JOIN RX_CLAIMS B ON A.CLAIM_ID = B.CLAM_ID AND A.PDE_SEQ = B.PDE_SEQ
			LEFT JOIN RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA_GAP C ON A.CLAIM_ID = C.CLAM_ID AND A.PDE_SEQ = C.PDE_SEQ
			JOIN MB_ENROLLEE_INFO D ON B.RX_MEME_ID = D.MEMBER_ID
			LEFT JOIN RX_NDC_DRUGS E ON B.DRUG_NDC_CODE = E.DRUG_NDC_CODE
				WHERE ' + @pWhereCondition + '
				order by CLAM_ORIGINAL_ENTRY_DATE'

		PRINT @pSQL

		EXEC sp_executesql @pSQL
			,N'@pDyanmicStatusVariable nvarchar(75)'
			,@pDyanmicStatusVariable = @pPdeStatus
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

PRINT N'Altering [dbo].[PDE_REC_MEMBER_DETAILS]'
GO

ALTER PROCEDURE [dbo].[PDE_REC_MEMBER_DETAILS] (
	@pKey VARCHAR(50) = ''
	,@pAccuYear VARCHAR(4) = ''
	,@pPdeStatus VARCHAR(10) = ''
	,@pProductID NVARCHAR(10) = NULL
	,@pGroupField NVARCHAR(100) = ''
	,@pGroupValue NVARCHAR(max) = ''
	,@pFieldName VARCHAR(8000) = ''
	,@pMonth NVARCHAR(2) = ''
	,@pFirstErrorOnly VARCHAR(1) = ''
	,@pSQL NVARCHAR(max) = '' OUTPUT
	)
AS
BEGIN
	DECLARE @WhereCondition NVARCHAR(max) = ''
		,@type VARCHAR(55) = ''
		,@switch VARCHAR(55) = ''
		,@string NVARCHAR(500) = ''
		,@pos INT
		,@piece NVARCHAR(500)
		,@counter INT
		,@pErrorCodes VARCHAR(50)
		,@pFromStatement NVARCHAR(max) = ''
		,@MemberID NVARCHAR(25) = ''

	--SET DEFAULT PARAMETERS
	IF @pAccuYear IS NULL
		OR @pAccuYear = ''
		SET @pAccuYear = YEAR(GETDATE())
	SET @MemberID = (
			SELECT RX_MEME_ID
			FROM RX_CLAIMS
			WHERE CLAM_ID = @pKey
			)

	IF @MemberID IS NULL
		OR @MemberID = ''
		SET @MemberID = '19961108510900'
	--PRINT @MemberID
	SET @pFromStatement = CASE 
			WHEN upper(@pFirstErrorOnly) = 'Y'
				THEN 'FROM dbo.RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA A
		JOIN RX_CLAIMS B ON A.CLAIM_ID = B.CLAM_ID AND A.PDE_SEQ = B.PDE_SEQ
		LEFT join RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA_GAP C ON A.CLAIM_ID = C.CLAM_ID AND A.PDE_SEQ = C.PDE_SEQ
		JOIN MB_ENROLLEE_INFO D ON B.RX_MEME_ID = D.MEMBER_ID
		LEFT JOIN RX_NDC_DRUGS E ON B.DRUG_NDC_CODE = E.DRUG_NDC_CODE
		JOIN dbo.RX_CMS_PDED_DETAIL_ERROR_CODE PDEDD ON A.CLAIM_ID=PDEDD.CLAIM_ID AND A.ERROR_SUBMISSION_NUM = PDEDD.ERROR_SUBMISSION_NUM AND SUBSTRING(A.ERROR_CODE,1,3) = PDEDD.ERROR_CODE
		JOIN dbo.PDE_REJECT_CODE PDER on PDEDD.ERROR_CODE = PDER.ERROR_CODE'
			ELSE 'FROM dbo.RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA A
		INNER JOIN RX_CLAIMS B ON A.CLAIM_ID = B.CLAM_ID AND A.PDE_SEQ = B.PDE_SEQ 
		LEFT join RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA_GAP C ON A.CLAIM_ID = C.CLAM_ID AND A.PDE_SEQ = C.PDE_SEQ
		JOIN MB_ENROLLEE_INFO D ON B.RX_MEME_ID = D.MEMBER_ID
		LEFT JOIN RX_NDC_DRUGS E ON B.DRUG_NDC_CODE = E.DRUG_NDC_CODE
		INNER JOIN dbo.RX_CMS_PDED_DETAIL_ERROR_CODE PDEDD ON A.CLAIM_ID=PDEDD.CLAIM_ID
		INNER JOIN dbo.PDE_REJECT_CODE PDER ON PDEDD.ERROR_CODE = PDER.ERROR_CODE AND A.ERROR_SUBMISSION_NUM = PDEDD.ERROR_SUBMISSION_NUM'
			END
	--Set columns for select statement
	SET @pSQL = 
		'SELECT B.RX_MEME_ID AS MEMBER_ID,
		    B.CLAM_ID,
			MEMBER_NAME,
			RIGHT(CSPI_ID,1) as [LICS_TIER],
			CASE WHEN BSDL_MCTR_TYPE = 0 THEN CLAM_DRUG_TYPE ELSE BSDL_MCTR_TYPE END as [DRUG_TIER],
			CLAM_CHECK_REFERENCE_NUMBER AS [PBM_ID], 
			E.DRUG_NDC_CODE as DRUG_NDC,
			CLAM_ORIGINAL_ENTRY_DATE AS PAID_DT,
		   (CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (INGREDIENT_COST_PAID+DISPENSING_FEE_PAID)  
			ELSE  (0 - (INGREDIENT_COST_PAID+DISPENSING_FEE_PAID)) END) AS [COST],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (A.PATIENT_PAY_AMOUNT)  
			ELSE  (0 - (A.PATIENT_PAY_AMOUNT)) END) AS [COPAY],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (A.LICS)  
			ELSE  (0 - (A.LICS)) END) AS [LICS],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (GDCB)  
			ELSE  (0 - (GDCB)) END) AS [GDCB],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (A.CPP)  
			ELSE  (0 - (A.CPP)) END) AS [CPP],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (PLRO)  
			ELSE  (0 - (PLRO)) END) AS [PLRO],
			E.DRUG_NAME,
			FILL_DT,
			A.TGCDCA AS TGCDCA,
			A.TrOOPA AS TROOPA,
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (CGDP)  
			ELSE  (0 - (CGDP)) END) AS [CGDP],
			(GDCA)  AS [GDCA],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (A.NPP)  
			ELSE  (0 - (A.NPP)) END) AS [NPP],'
	SET @pSQL = @pSQL + '
			(P_LEVEL_P1)  AS [COPAY_DEDUCT],
			(P_LEVEL_P2)  AS [COPAY_COV],
			(P_LEVEL_P3)  AS [COPAY_GAP],
			(P_LEVEL_P4)  AS [COPAY_CAT],
			(P_LEVEL1) AS [COST_DEDUCT],
			(P_LEVEL2) AS [COST_COV],
			(P_LEVEL3) AS [COST_GAP],
			(P_LEVEL4) AS [COST_CAT],
			(P_LEVEL_P1+P_LEVEL_P2+P_LEVEL_P3+P_LEVEL_P4) AS [COPAY_TOT],
			(P_LEVEL1+P_LEVEL2+P_LEVEL3+P_LEVEL4) AS [COST_TOTAL],
			(C.LICS) AS PBM_LICS,
			''0.00'' AS LICS_FAKE'

	--If set to All, will collect all information for member
	IF @pFieldName <> 'ALL'
	BEGIN
		--parse _ delimited FieldName parameter.  Use the variable @type in both Rej and (ACC or OUT or INF or ALL)
		SET @string = @pFieldName
		SET @counter = 1

		IF right(RTRIM(@string), 1) <> '_'
			SELECT @string = @string + '_'

		SELECT @pos = patindex('%[_]%', @string)

		WHILE @pos <> 0
		BEGIN
			SELECT @piece = left(@string, (@pos - 1))

			IF @counter = 1
				SET @type = cast(@piece AS NVARCHAR(512))
			SET @counter = @counter + 1

			SELECT @string = stuff(@string, 1, @pos, '')

			SELECT @pos = patindex('%[_]%', @string)
		END
	END

	PRINT @type

	IF @pPdeStatus = 'REJ'
	BEGIN
		IF (
				@pGroupField IS NULL
				OR @pGroupField = ''
				)
			SET @pGroupField = 'ERROR_AGING'

		--Group value is the type of chart on PDE rej page
		--print @pGroupValue
		IF (
				@pGroupValue IS NULL
				OR @pGroupValue = ''
				)
		BEGIN
			SET @pGroupValue = CASE 
					WHEN @pGroupField = 'ERROR_AGING'
						THEN '%'
					WHEN @pGroupField = 'EDIT_CATEGORY'
						THEN '%'
					WHEN @pGroupField = 'SERVICE_YEAR'
						THEN '%'
					WHEN @pGroupField = 'RESUBMIT'
						THEN '%'
					END
		END

		IF (
				@pFieldName IS NULL
				OR @pFieldName = ''
				)
			SET @pFieldName = 'ERRORS_AMOUNT'

		IF (
				@pProductID IS NULL
				OR @pProductID = ''
				)
			SET @pProductID = '%%'

		--if you don't have a conditional for serivce year, you will end up with a duplicate YEAR(PAID_DT) = X
		IF @pGroupField <> 'SERVICE_YEAR'
			SET @WhereCondition = ' AND YEAR(A.PAID_DT) = ''' + @pAccuYear + ''' '

		--		IF NOT (@pMonth is null or @pMonth = '') and @pGroupField = 'TREND' 
		-- 7/27/2014 Add Month option to the query
		IF NOT (
				@pMonth IS NULL
				OR @pMonth = ''
				)
			SET @WhereCondition = @WhereCondition + ' AND MONTH(A.PAID_DT) = ''' + @pMonth + ''''
		SET @WhereCondition = @WhereCondition + 'AND PDPD_ID LIKE ''' + @pProductID + ''' '

		--ALL = CAT + COST + ERRORS + NDC + LICS + GAP + ENROLL
		IF @pFieldName <> 'ALL'
		BEGIN
			PRINT @pFieldName

			--set @pErrorCodes to proper nomenclature
			SET @pErrorCodes = CASE 
					WHEN @type = 'CAT'
						THEN 'Catastrophic'
					WHEN @type = 'COST'
						THEN 'Claims Cost'
					WHEN @type = 'ERRORS'
						THEN 'Claims Errors'
					WHEN @type = 'NDC'
						THEN 'Drug NDC Code'
					WHEN @type = 'LICS'
						THEN 'Claims LICS'
					WHEN @type = 'GAP'
						THEN 'Gap Discount'
					WHEN @type = 'ENROLL'
						THEN 'Member Enrollment'
					END
			--add this to pCode
			SET @WhereCondition = @WhereCondition + ' AND PDER.EDIT_CATEGORY = ''' + @pErrorCodes + ''''

			--Set value for condition
			IF @pGroupValue = '%'
				SET @switch = CASE 
						WHEN @pGroupField = 'ERROR_AGING'
							THEN ' AGING.CODE_TYPE_DESC LIKE '''
						WHEN @pGroupField = 'EDIT_CATEGORY'
							THEN ' EDITES LIKE '''
						WHEN @pGroupField = 'RESUBMIT'
							THEN ' A.ERROR_SUBMISSION_NUM LIKE '''
						WHEN @pGroupField = 'SERVICE_YEAR'
							THEN ' YEAR(A.FILL_DT) LIKE '''
						END
			ELSE
				SET @switch = CASE 
						WHEN @pGroupField = 'ERROR_AGING'
							THEN ' AGING.CODE_TYPE_DESC = '''
						WHEN @pGroupField = 'EDIT_CATEGORY'
							THEN ' EDITES LIKE '''
						WHEN @pGroupField = 'RESUBMIT'
							THEN ' A.ERROR_SUBMISSION_NUM ='''
						WHEN @pGroupField = 'SERVICE_YEAR'
							THEN ' YEAR(A.FILL_DT) = '''
						END

			--print @pGroupField
			--parse _ delimited GroupValue parameter, not required for Trend graph
			IF @pGroupField <> 'TREND'
			BEGIN
				SET @counter = 1
				SET @WhereCondition = @WhereCondition + ' AND ('
				SET @string = @pGroupValue

				IF right(RTRIM(@string), 1) <> '|'
					SELECT @string = @string + '|'

				SELECT @pos = patindex('%[|]%', @string)

				WHILE @pos <> 0
				BEGIN
					SELECT @piece = left(@string, (@pos - 1))

					--build pCode String
					IF @counter <> 1
						SET @WhereCondition = @WhereCondition + 'OR '

					--only select numbers from resubmit, I.E. Change "2 resubmission" to "2"
					IF @pGroupField = 'RESUBMIT'
						SET @piece = SUBSTRING(@piece, 1, CHARINDEX(' ', @piece) - 1)

					IF @pGroupField = 'EDIT_CATEGORY'
						SET @WhereCondition = @WhereCondition + @switch + @piece + '%'' '
					ELSE
						SET @WhereCondition = @WhereCondition + @switch + @piece + ''' '

					SET @counter = @counter + 1

					SELECT @string = stuff(@string, 1, @pos, '')

					SELECT @pos = patindex('%[|]%', @string)
				END

				SET @WhereCondition = @WhereCondition + ' )'
			END
		END

		--Add extra columns for Rejected Member Pop up
		SET @pSQL = @pSQL + ', PDER.ERROR_CODE, EDITES
		' + @pFromStatement + '
		JOIN SUP_SUPPORT_CODE AGING ON CODE_TYPE=''DAY_RANGE'' AND DATEDIFF(DAY,BATCH_DATE,GETDATE()) BETWEEN CAST(CODE AS INT) AND CAST(CODE_DESC AS INT)
		LEFT JOIN MB_MEMBER_ELIGIBILITY ELIG ON B.MEMBER_CK = ELIG.MEMBER_CK AND B.CLAM_FILL_DATE BETWEEN EFFECTIVE_DATE AND TERMINATION_DATE
		WHERE DRUG_COVERAGE_STATUS_CODE IN (''C'',''E'',''O'') and A.STATUS=''REJ'' AND B.RX_MEME_ID = ''' + @MemberID + '''' + @WhereCondition + ' order by CLAM_ORIGINAL_ENTRY_DATE,CLAM_FILL_DATE,B.TGCDCA,CLAM_ID'

		--create temporary table to store results of pop up (ERROR CODES AND EDITES)
		---used to seperate formatting of text (<br><br\>) and select query
		CREATE TABLE #temp (
			MEMBER_ID NVARCHAR(100)
			,CLAM_ID NVARCHAR(25)
			,MEMBER_NAME NVARCHAR(100)
			,LICS_TIER NVARCHAR(10)
			,DRUG_TIER NVARCHAR(10)
			,PBM_ID NVARCHAR(100)
			,DRUG_NDC NVARCHAR(100)
			,PAID_DT DATE
			,COST MONEY
			,COPAY MONEY
			,LICS MONEY
			,GDCB MONEY
			,CPP MONEY
			,PLRO MONEY
			,DRUG_NAME NVARCHAR(100)
			,FILL_DT DATE
			,TGCDCA MONEY
			,TROOPA MONEY
			,CGDP MONEY
			,GDCA MONEY
			,NPP MONEY
			,COPAY_DEDUCT MONEY
			,COPAY_COV MONEY
			,COPAY_GAP MONEY
			,COPAY_CAT MONEY
			,COST_DEDUCT MONEY
			,COST_COV MONEY
			,COST_GAP MONEY
			,COST_CAT MONEY
			,COPAY_TOT MONEY
			,COST_TOTAL MONEY
			,PBM_LICS MONEY
			,FAKE_LICS MONEY
			,ERROR_CODE NVARCHAR(100)
			,EDITES NVARCHAR(max)
			)

		--insert data into the temporary table
		INSERT INTO #temp
		EXEC sp_executesql @pSQL
			,N'@pPDE_STAT nvarchar(75)'
			,@pPDE_STAT = @pPdeStatus

		--reformat the 
		SELECT DISTINCT MEMBER_ID
			,CLAM_ID
			,MEMBER_NAME
			,LICS_TIER
			,DRUG_TIER
			,PBM_ID
			,DRUG_NDC
			,PAID_DT
			,COST
			,COPAY
			,LICS
			,GDCB
			,CPP
			,PLRO
			,DRUG_NAME
			,FILL_DT
			,TGCDCA
			,TROOPA
			,CGDP
			,GDCA
			,NPP
			,COPAY_DEDUCT
			,COPAY_COV
			,COPAY_GAP
			,COPAY_CAT
			,COST_DEDUCT
			,COST_COV
			,COST_GAP
			,COST_CAT
			,COPAY_TOT
			,COST_TOTAL
			,PBM_LICS
			,FAKE_LICS
			,
			--creates a - delimited list for each claim
			STUFF((
					SELECT '-' + A.[ERROR_CODE]
					FROM #temp A
					WHERE A.[PBM_ID] = B.[PBM_ID]
					FOR XML PATH('')
						,type
					).value('.', 'nvarchar(max)'), 1, 1, '') AS [ERROR_CODE]
			,
			--creates a ',' delimited list for error descriptions
			--stuff will create an extra ',' at the begining of the string, substring removes this
			STUFF((
					SELECT ' - ' + A.[EDITES]
					FROM #temp A
					WHERE A.[PBM_ID] = B.[PBM_ID]
					FOR XML PATH('')
						,type
					).value('.', 'nvarchar(max)'), 1, 1, '') AS [EDITES]
		FROM #temp B
	END
	ELSE
	BEGIN
		--build condition for status that should be returned, ALL = INF + ACC + OUT + REJ
		SET @WhereCondition = CASE 
				WHEN (@pPdeStatus = 'ALL')
					THEN ' '
				WHEN @pPdeStatus = 'ACC'
					THEN 'A.STATUS IN (''ACC'',''INF'', ''CLN'') AND '
				WHEN @pPdeStatus = 'INF'
					THEN 'A.STATUS IN (''ACC'',''INF'', ''CLN'') AND '
				WHEN @pPdeStatus = NULL
					OR @pPdeStatus = ''
					THEN ' A.STATUS IS NULL AND '
				END

		IF NOT (
				@pMonth IS NULL
				OR @pMonth = ''
				)
			SET @WhereCondition = @WhereCondition + '  MONTH(A.PAID_DT) = ''' + @pMonth + ''' AND '

		IF @pFieldName <> 'ALL'
		BEGIN
			--set @WhereCondition to proper nomenclature
			SET @WhereCondition = CASE 
					WHEN @type = 'OTC'
						THEN @WhereCondition + ' DRUG_COVERAGE_STATUS_CODE = ''O'''
					WHEN @type = 'ENHANCED'
						THEN @WhereCondition + ' DRUG_COVERAGE_STATUS_CODE = ''E'''
					WHEN @type = 'COVERED'
						THEN @WhereCondition + ' DRUG_COVERAGE_STATUS_CODE = ''C'''
					WHEN (
							@type <> 'OTC'
							AND @type <> 'ENHANCED'
							AND @type <> 'COVERED'
							)
						THEN @WhereCondition + 'A.' + @type + ' <> 0 '
					END
		END

		SET @pSQL = @pSQL + '
				FROM dbo.RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA A
			JOIN RX_CLAIMS B ON A.CLAIM_ID = B.CLAM_ID AND A.PDE_SEQ = B.PDE_SEQ
			LEFT join RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA_GAP C ON A.CLAIM_ID = C.CLAM_ID AND A.PDE_SEQ = C.PDE_SEQ
			JOIN MB_ENROLLEE_INFO D ON B.RX_MEME_ID = D.MEMBER_ID
			FULL JOIN RX_NDC_DRUGS E ON B.DRUG_NDC_CODE = E.DRUG_NDC_CODE
				WHERE ' + @WhereCondition + ' AND B.RX_MEME_ID = ''' + @MemberID + ''' and YEAR(PAID_DT) = ''' + @pAccuYear + ''' AND DRUG_COVERAGE_STATUS_CODE IN (''C'',''E'',''O'')
	
				order by CLAM_ORIGINAL_ENTRY_DATE,CLAM_FILL_DATE,B.TGCDCA,CLAM_ID'

		--print @pSQL
		EXEC sp_executesql @pSQL
			,N'@pPDE_STAT nvarchar(75)'
			,@pPDE_STAT = @pPdeStatus
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

PRINT N'Creating [dbo].[PDE_FIR_POP_SUMMARY_TITLE]'
GO

-- PDE_FIR_POP_SUMMARY @pMemberID=''
CREATE PROCEDURE [dbo].[PDE_FIR_POP_SUMMARY_TITLE] (
	@pAccuYear VARCHAR(4) = ''
	,@pFieldName VARCHAR(50) = ''
	,@pFirStatus VARCHAR(10) = ''
	,@pMonth VARCHAR(2) = ''
	,@pMemberID VARCHAR(25) = ''
	,@pProductID NVARCHAR(10) = NULL
	,@pSQL NVARCHAR(max) = '' OUTPUT
	)
AS
BEGIN
	DECLARE @pWhereCondition VARCHAR(4000) = ''
		,@TransferInOrOut VARCHAR(10) = ''
	--select plan id's
	DECLARE @planID VARCHAR(8000)

	SELECT @planID = COALESCE(@planID + ''','' ', '') + CODE
	FROM SUP_SUPPORT_CODE
	WHERE CODE_TYPE = 'PLAN_ID'
		AND CODE IS NOT NULL

	--set default value
	SET @TransferInOrOut = CASE 
			WHEN @pFirStatus = 'In'
				THEN 'F2'
			ELSE 'F1'
			END

	DECLARE @Outstanding VARCHAR(2500) = '((ISNULL(t.TRANSACTION_CODE,'''') <> ''' + @TransferInOrOut + '''  and not (e.PRE_AFTER_PLAN_ID IS NULL OR e.PRE_AFTER_PLAN_ID = '''') )) '
		,@Received VARCHAR(2500) = '(t.TRANSACTION_CODE = ''' + @TransferInOrOut + '''' + ' AND YEAR(t.TERMINATION_DATE) = ''' + @pAccuYear + '''' + ')'
		,@Required VARCHAR(2500) = '(t.TRANSACTION_CODE = ''' + @TransferInOrOut + '''  OR (ISNULL(t.TRANSACTION_CODE,'''') = ''''   and not (e.PRE_AFTER_PLAN_ID IS NULL OR e.PRE_AFTER_PLAN_ID = '''') ))'
		,@Errors VARCHAR(2500) = ' (t.FIR_APPLIED_TO_CLAIM = ''F'' )'

	IF @pAccuYear IS NULL
		OR @pAccuYear = ''
		SET @pAccuYear = YEAR(GETDATE())

	IF @pFirStatus IS NULL
		OR @pFirStatus = ''
		SET @pFirStatus = 'In'

	IF @pFieldName IS NULL
		OR @pFieldName = ''
		SET @pFieldName = 'RECEIVED_FIR'

	IF @pMemberID IS NULL
		OR @pMemberID = ''
		SET @pMemberID = '20010900124700'
	SET @pWhereCondition = CASE 
			WHEN @pFirStatus = 'In'
				THEN ' TRANSACTION_TYPE in (''NE'',''RI'') AND TRANSACTION_VOID_IND=''N'' '
			WHEN @pFirStatus = 'Out'
				THEN ' TRANSACTION_TYPE=''TM'' AND TRANSACTION_VOID_IND=''N'''
			END
	SET @pWhereCondition = @pWhereCondition + ' AND YEAR(e.PRODUCT_EFF_DATE) = ''' + @pAccuYear + ''' ' + ' and (e.PRE_AFTER_PLAN_ID NOT IN (''' + @planID + '''' + ') or e.PRE_AFTER_PLAN_ID is null or e.PRE_AFTER_PLAN_ID  = '''') '
	SET @pWhereCondition = @pWhereCondition + ' AND ' + CASE 
			WHEN @pFieldName = 'RECEIVED_FIR'
				AND @pFirStatus = 'In'
				THEN @Received
			WHEN @pFieldName = 'REQUIRED_FIR'
				AND @pFirStatus = 'In'
				THEN @Required
			WHEN @pFieldName = 'RECEIVED_FIR'
				AND @pFirStatus = 'Out'
				THEN @Received
			WHEN @pFieldName = 'REQUIRED_FIR'
				AND @pFirStatus = 'Out'
				THEN @Required
			WHEN @pFieldName = 'OUTSTANDING_FIR'
				THEN @Outstanding
			WHEN @pFieldName = 'ENROLLEMENT'
				THEN ' m.MEMBER_ID IS NOT NULL '
			WHEN @pFieldName = 'TROOP'
				THEN ' t.APPLIED_TROOP_AMOUNT  IS NOT NULL '
			WHEN @pFieldName = 'COST'
				THEN ' t.APPLIED_DRUG_COST IS NOT NULL'
			WHEN @pFieldName = 'ERRORS'
				THEN @Errors
			END
	SET @pWhereCondition = @pWhereCondition + ' AND m.MEMBER_ID = ''' + @pMemberID + ''' '

	IF @pMonth <> ''
		SET @pWhereCondition = @pWhereCondition + ' AND MONTH(e.PRODUCT_EFF_DATE) = ''' + @pMonth + ''' '
	SET @pSQL = 'SELECT  TITLE, COLOR_PICKER FROM (SELECT DISTINCT 
	m.MEMBER_ID AS MEMBER_ID,
	
	''=#Other Plan: ''
	 + (CASE WHEN PRE_AFTER_PLAN_ID IS NULL OR PRE_AFTER_PLAN_ID = '''' THEN ''NA'' ELSE PRE_AFTER_PLAN_ID END)
	 + ''#==#'' 
	+ISNULL(f.CONTRACT_NAME,''NA'')+''#='' as TITLE,
	NULL as COLOR_PICKER,' + CASE 
			WHEN @pFirStatus = 'Out'
				THEN 'PRODUCT_EFF_DATE AS PRODUCT_EFF_DATE'
			WHEN @pFirStatus = 'In'
				THEN 'PRODUCT_EFF_DATE'
			END + ',t.APPLIED_DRUG_COST AS COST,
	 t.AMOUNT_APPLIED_TO_CLAIM,
	t.CLAIM_COST_BEFORE_FIR,
	 t.APPLIED_TROOP_AMOUNT AS TROOP_AMOUNT,
	 t.FIR_APPLIED_TO_CLAIM,
	 t.TRANSACTION_DATE AS DATE_FIR_APPLIED 
	from MB_MEMBER_PRODUCTS e
	left join RX_BALANCE_TRANSFER t on e.MEMBER_CK = t.MEMBER_CK AND YEAR(t.TERMINATION_DATE) = ''' + @pAccuYear + ''' and e.PLAN_ID = t.PLAN_ID and t.TRANSACTION_CODE = ''' + @TransferInOrOut + ''' 
    RIGHT JOIN MB_ENROLLEE_INFO m ON e.MEMBER_CK=m.MEMBER_CK
    left join [SUP_P2P_PLAN_NAME] f ON e.PRE_AFTER_PLAN_ID = f.CONTRACT_ID
    WHERE ' + @pWhereCondition + ' 
	) DATA
	ORDER BY YEAR(PRODUCT_EFF_DATE), MONTH(PRODUCT_EFF_DATE), MEMBER_ID'

	PRINT @pSQL

	EXEC sp_executesql @pSQL
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

PRINT N'Altering [dbo].[PDE_REC_CLAIM_DETAILS_REJ]'
GO

ALTER PROCEDURE [dbo].[PDE_REC_CLAIM_DETAILS_REJ] (
	@pKey VARCHAR(50) = ''
	,@pPdeStatus VARCHAR(10) = ''
	,@pProductID NVARCHAR(10) = NULL
	,@pMonth NVARCHAR(2) = ''
	,@pFirstErrorOnly VARCHAR(1) = ''
	,@pSQL NVARCHAR(max) = '' OUTPUT
	)
AS
BEGIN
	DECLARE @pWhereCondition NVARCHAR(max) = ''
		,@pFromStatement NVARCHAR(max) = ''
		,@JoinParameter NVARCHAR(1000) = ''
		,@PbmID NVARCHAR(50) = ''
		,@ClaimID NVARCHAR(50) = ''

	SET @ClaimID = @pKey

	--SET DEFAULT PARAMETERS
	IF @ClaimID IS NULL
		OR @ClaimID = ''
		SET @ClaimID = '1826937'

	SELECT @PbmID = (
			SELECT CLAM_CHECK_REFERENCE_NUMBER
			FROM RX_CLAIMS
			WHERE CLAM_ID = @ClaimID
			)

	SET @pWhereCondition = 'CLAM_CHECK_REFERENCE_NUMBER= ''' + @PbmID + ''' AND DRUG_COVERAGE_STATUS_CODE IN (''C'',''E'',''O'') AND A.STATUS = ''REJ'' '
	--PRINT @PbmID
	SET @pFromStatement = CASE 
			WHEN upper(@pFirstErrorOnly) = 'Y'
				THEN 'FROM dbo.RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA A
		JOIN RX_CLAIMS B ON A.CLAIM_ID = B.CLAM_ID --AND A.PDE_SEQ = B.PDE_SEQ
		LEFT join RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA_GAP C ON A.CLAIM_ID = C.CLAM_ID AND A.PDE_SEQ = C.PDE_SEQ
		JOIN MB_ENROLLEE_INFO D ON B.RX_MEME_ID = D.MEMBER_ID
		LEFT JOIN RX_NDC_DRUGS E ON B.DRUG_NDC_CODE = E.DRUG_NDC_CODE
		JOIN dbo.RX_CMS_PDED_DETAIL_ERROR_CODE PDEDD ON A.CLAIM_ID=PDEDD.CLAIM_ID AND A.ERROR_SUBMISSION_NUM = PDEDD.ERROR_SUBMISSION_NUM AND SUBSTRING(A.ERROR_CODE,1,3) = PDEDD.ERROR_CODE
		JOIN dbo.PDE_REJECT_CODE PDER on PDEDD.ERROR_CODE = PDER.ERROR_CODE'
			ELSE 'FROM dbo.RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA A
		INNER JOIN RX_CLAIMS B ON A.CLAIM_ID = B.CLAM_ID --AND A.PDE_SEQ = B.PDE_SEQ 
		LEFT join RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA_GAP C ON A.CLAIM_ID = C.CLAM_ID AND A.PDE_SEQ = C.PDE_SEQ
		JOIN MB_ENROLLEE_INFO D ON B.RX_MEME_ID = D.MEMBER_ID
		LEFT JOIN RX_NDC_DRUGS E ON B.DRUG_NDC_CODE = E.DRUG_NDC_CODE
		INNER JOIN dbo.RX_CMS_PDED_DETAIL_ERROR_CODE PDEDD ON A.CLAIM_ID=PDEDD.CLAIM_ID
		INNER JOIN dbo.PDE_REJECT_CODE PDER ON PDEDD.ERROR_CODE = PDER.ERROR_CODE AND A.ERROR_SUBMISSION_NUM = PDEDD.ERROR_SUBMISSION_NUM'
			END
	--Set columns for select statement
	SET @pSQL = 
		'(SELECT B.RX_MEME_ID AS MEMBER_ID,
			MEMBER_NAME,
			B.CLAM_ID,
			RIGHT(CSPI_ID,1) as [LICS_TIER],
			CASE WHEN BSDL_MCTR_TYPE = 0 THEN CLAM_DRUG_TYPE ELSE BSDL_MCTR_TYPE END as [DRUG_TIER],
			A.STATUS,
			CLAM_CHECK_REFERENCE_NUMBER AS [PBM_ID], 
			E.DRUG_NDC_CODE as DRUG_NDC,
			CLAM_ORIGINAL_ENTRY_DATE AS PAID_DT,
		   (CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (INGREDIENT_COST_PAID+DISPENSING_FEE_PAID)  
			ELSE  (0 - (INGREDIENT_COST_PAID+DISPENSING_FEE_PAID)) END) AS [COST],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (A.PATIENT_PAY_AMOUNT)  
			ELSE  (0 - (A.PATIENT_PAY_AMOUNT)) END) AS [COPAY],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (A.LICS)  
			ELSE  (0 - (A.LICS)) END) AS [LICS],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (GDCB)  
			ELSE  (0 - (GDCB)) END) AS [GDCB],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (A.CPP)  
			ELSE  (0 - (A.CPP)) END) AS [CPP],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (PLRO)  
			ELSE  (0 - (PLRO)) END) AS [PLRO],
			E.DRUG_NAME,
			FILL_DT,
			A.TGCDCA AS TGCDCA,
			A.TrOOPA AS TROOPA,
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (CGDP)  
			ELSE  (0 - (CGDP)) END) AS [CGDP],
			(GDCA)  AS [GDCA],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (A.NPP)  
			ELSE  (0 - (A.NPP)) END) AS [NPP],'
	SET @pSQL = @pSQL + '
			(P_LEVEL_P1)  AS [COPAY_DEDUCT],
			(P_LEVEL_P2)  AS [COPAY_COV],
			(P_LEVEL_P3)  AS [COPAY_GAP],
			(P_LEVEL_P4)  AS [COPAY_CAT],
			(P_LEVEL1) AS [COST_DEDUCT],
			(P_LEVEL2) AS [COST_COV],
			(P_LEVEL3) AS [COST_GAP],
			(P_LEVEL4) AS [COST_CAT],
			(P_LEVEL_P1+P_LEVEL_P2+P_LEVEL_P3+P_LEVEL_P4) AS [COPAY_TOT],
			(P_LEVEL1+P_LEVEL2+P_LEVEL3+P_LEVEL4) AS [COST_TOTAL],
			(C.LICS) AS PBM_LICS,
			''0.00'' AS LICS_FAKE,
			ADJUSTMENT_DELETE_CODE'
	SET @pSQL = @pSQL + ',PDER.ERROR_CODE, EDITES
		' + @pFromStatement + '
		JOIN SUP_SUPPORT_CODE AGING ON CODE_TYPE=''DAY_RANGE'' AND DATEDIFF(DAY,BATCH_DATE,GETDATE()) BETWEEN CAST(CODE AS INT) AND CAST(CODE_DESC AS INT)
		LEFT JOIN MB_MEMBER_ELIGIBILITY ELIG ON B.MEMBER_CK = ELIG.MEMBER_CK AND B.CLAM_FILL_DATE BETWEEN EFFECTIVE_DATE AND TERMINATION_DATE
		WHERE ' + @pWhereCondition + ' )'
	-- CONCTENATE ERROR CODES
	SET @pSQL = 'SELECT  DISTINCT MEMBER_ID ,
			MEMBER_NAME ,
			LICS_TIER,
			DRUG_TIER,
			CLAM_ID,
			PBM_ID , 
			DRUG_NDC ,
			PAID_DT ,
		   COST ,
		   STATUS,
			COPAY ,
			LICS ,
			GDCB ,
			CPP,
			PLRO ,
			DRUG_NAME ,
			FILL_DT  ,
			TGCDCA ,
			TROOPA ,
			CGDP ,
			GDCA ,
			NPP ,
			COPAY_DEDUCT ,
			COPAY_COV ,
			COPAY_GAP ,
			COPAY_CAT  ,
			COST_DEDUCT,
			COST_COV,
			COST_GAP,
			COST_CAT,
			COPAY_TOT,
			COST_TOTAL,
			PBM_LICS,
			LICS_FAKE as FAKE_LICS,
			ADJUSTMENT_DELETE_CODE, 

	--creates a - delimited list for each claim
	STUFF((SELECT ''-'' + A.[ERROR_CODE] FROM ' + @pSQL + ' A
		Where A.[CLAM_ID]=B.[CLAM_ID] FOR XML PATH('''')),1,1,'''') As [ERROR_CODE],
	--creates a '','' delimited list for error descriptions
	--stuff will create an extra '','' at the begining of the string, substring removes this
	STUFF((SELECT '', '' + A.[EDITES] FROM ' + @pSQL + '  A
		Where A.[CLAM_ID]=B.[CLAM_ID] FOR XML PATH('''')),1,1,'''') As [EDITES]
	FROM ' + @pSQL + 
		'  B 
	order by PAID_DT'

	PRINT cast(@pSQL AS TEXT)

	EXEC sp_executesql @pSQL
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

PRINT N'Altering [dbo].[PDE_REC_CLAIM_DETAILS_ADJ]'
GO

ALTER PROCEDURE [dbo].[PDE_REC_CLAIM_DETAILS_ADJ] (
	@pKey VARCHAR(50) = ''
	,@pPdeStatus VARCHAR(10) = ''
	,@pProductID NVARCHAR(10) = NULL
	,@pMonth NVARCHAR(2) = ''
	,@pFirstErrorOnly VARCHAR(1) = ''
	,@pSQL NVARCHAR(max) = '' OUTPUT
	)
AS
BEGIN
	DECLARE @pWhereCondition NVARCHAR(max) = ''
		,@pFromStatement NVARCHAR(max) = ''
		,@JoinParameter NVARCHAR(1000) = ''
		,@PbmID NVARCHAR(50) = ''
		,@ClaimID NVARCHAR(50) = ''

	SET @ClaimID = @pKey

	--SET DEFAULT PARAMETERS
	IF @ClaimID IS NULL
		OR @ClaimID = ''
		SET @ClaimID = '1826937'

	SELECT @PbmID = (
			SELECT CLAM_CHECK_REFERENCE_NUMBER
			FROM RX_CLAIMS
			WHERE CLAM_ID = @ClaimID
			)

	SET @pWhereCondition = 'CLAM_CHECK_REFERENCE_NUMBER = ''' + @PbmID + ''' AND DRUG_COVERAGE_STATUS_CODE IN (''C'',''E'',''O'')'
	--Set columns for select statement
	SET @pSQL = 
		'SELECT B.RX_MEME_ID AS MEMBER_ID,
			MEMBER_NAME,
			A.STATUS,
			CLAM_CHECK_REFERENCE_NUMBER AS [PBM_ID], 
			RIGHT(CSPI_ID,1) as [LICS_TIER],
			CASE WHEN BSDL_MCTR_TYPE = 0 THEN CLAM_DRUG_TYPE ELSE BSDL_MCTR_TYPE END as [DRUG_TIER],
			E.DRUG_NDC_CODE as DRUG_NDC,
			CLAM_ORIGINAL_ENTRY_DATE AS PAID_DT,
		   (CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (INGREDIENT_COST_PAID+DISPENSING_FEE_PAID)  
			ELSE  (0 - (INGREDIENT_COST_PAID+DISPENSING_FEE_PAID)) END) AS [COST],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (A.PATIENT_PAY_AMOUNT)  
			ELSE  (0 - (A.PATIENT_PAY_AMOUNT)) END) AS [COPAY],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (A.LICS)  
			ELSE  (0 - (A.LICS)) END) AS [LICS],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (GDCB)  
			ELSE  (0 - (GDCB)) END) AS [GDCB],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (A.CPP)  
			ELSE  (0 - (A.CPP)) END) AS [CPP],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (PLRO)  
			ELSE  (0 - (PLRO)) END) AS [PLRO],
			E.DRUG_NAME,
			FILL_DT,
			A.TGCDCA AS TGCDCA,
			A.TrOOPA AS TROOPA,
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (CGDP)  
			ELSE  (0 - (CGDP)) END) AS [CGDP],
			(GDCA)  AS [GDCA],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (A.NPP)  
			ELSE  (0 - (A.NPP)) END) AS [NPP],'
	SET @pSQL = @pSQL + '
			(P_LEVEL_P1)  AS [COPAY_DEDUCT],
			(P_LEVEL_P2)  AS [COPAY_COV],
			(P_LEVEL_P3)  AS [COPAY_GAP],
			(P_LEVEL_P4)  AS [COPAY_CAT],
			(P_LEVEL1) AS [COST_DEDUCT],
			(P_LEVEL2) AS [COST_COV],
			(P_LEVEL3) AS [COST_GAP],
			(P_LEVEL4) AS [COST_CAT],
			(P_LEVEL_P1+P_LEVEL_P2+P_LEVEL_P3+P_LEVEL_P4) AS [COPAY_TOT],
			(P_LEVEL1+P_LEVEL2+P_LEVEL3+P_LEVEL4) AS [COST_TOTAL],
			(C.LICS) AS PBM_LICS,
			''0.00'' AS LICS_FAKE,
			ADJUSTMENT_DELETE_CODE'
	SET @pSQL = @pSQL + '
				FROM dbo.RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA A
			JOIN RX_CLAIMS B ON A.CLAIM_ID = B.CLAM_ID --AND A.PDE_SEQ = B.PDE_SEQ
			LEFT JOIN RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA_GAP C ON A.CLAIM_ID = C.CLAM_ID AND A.PDE_SEQ = C.PDE_SEQ
			JOIN MB_ENROLLEE_INFO D ON B.RX_MEME_ID = D.MEMBER_ID
			LEFT JOIN RX_NDC_DRUGS E ON B.DRUG_NDC_CODE = E.DRUG_NDC_CODE
				WHERE ' + @pWhereCondition + '
				order by CLAM_ORIGINAL_ENTRY_DATE'

	PRINT @pSQL

	EXEC sp_executesql @pSQL
		,N'@pDyanmicStatusVariable nvarchar(75)'
		,@pDyanmicStatusVariable = @pPdeStatus
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

PRINT N'Altering [dbo].[PDE_REC_CLAIM_DETAILS_OUT]'
GO

ALTER PROCEDURE [dbo].[PDE_REC_CLAIM_DETAILS_OUT] (
	@pKey VARCHAR(50) = ''
	,@pPdeStatus VARCHAR(10) = ''
	,@pProductID NVARCHAR(10) = NULL
	,@pMonth NVARCHAR(2) = ''
	,@pFirstErrorOnly VARCHAR(1) = ''
	,@pSQL NVARCHAR(max) = '' OUTPUT
	)
AS
BEGIN
	DECLARE @pWhereCondition NVARCHAR(max) = ''
		,@pFromStatement NVARCHAR(max) = ''
		,@JoinParameter NVARCHAR(1000) = ''
		,@PbmID NVARCHAR(50) = ''
		,@ClaimID NVARCHAR(50) = ''

	SET @ClaimID = @pKey

	--SET DEFAULT PARAMETERS
	IF @ClaimID IS NULL
		OR @ClaimID = ''
		SET @ClaimID = '1826937'

	SELECT @PbmID = (
			SELECT CLAM_CHECK_REFERENCE_NUMBER
			FROM RX_CLAIMS
			WHERE CLAM_ID = @ClaimID
			)

	SET @pWhereCondition = 'CLAM_CHECK_REFERENCE_NUMBER = ''' + @PbmID + ''' AND DRUG_COVERAGE_STATUS_CODE IN (''C'',''E'',''O'')'
	--Set columns for select statement
	SET @pSQL = 
		'SELECT B.RX_MEME_ID AS MEMBER_ID,
			MEMBER_NAME,
			CLAM_CHECK_REFERENCE_NUMBER AS [PBM_ID], 
			E.DRUG_NDC_CODE as DRUG_NDC,
			CLAM_ORIGINAL_ENTRY_DATE AS PAID_DT,
		   (CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (INGREDIENT_COST_PAID+DISPENSING_FEE_PAID)  
			ELSE  (0 - (INGREDIENT_COST_PAID+DISPENSING_FEE_PAID)) END) AS [COST],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (A.PATIENT_PAY_AMOUNT)  
			ELSE  (0 - (A.PATIENT_PAY_AMOUNT)) END) AS [COPAY],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (A.LICS)  
			ELSE  (0 - (A.LICS)) END) AS [LICS],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (GDCB)  
			ELSE  (0 - (GDCB)) END) AS [GDCB],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (A.CPP)  
			ELSE  (0 - (A.CPP)) END) AS [CPP],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (PLRO)  
			ELSE  (0 - (PLRO)) END) AS [PLRO],
			E.DRUG_NAME,
			FILL_DT,
			A.TGCDCA AS TGCDCA,
			A.TrOOPA AS TROOPA,
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (CGDP)  
			ELSE  (0 - (CGDP)) END) AS [CGDP],
			(GDCA)  AS [GDCA],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (A.NPP)  
			ELSE  (0 - (A.NPP)) END) AS [NPP],'
	SET @pSQL = @pSQL + '
			(P_LEVEL_P1)  AS [COPAY_DEDUCT],
			(P_LEVEL_P2)  AS [COPAY_COV],
			(P_LEVEL_P3)  AS [COPAY_GAP],
			(P_LEVEL_P4)  AS [COPAY_CAT],
			(P_LEVEL1) AS [COST_DEDUCT],
			(P_LEVEL2) AS [COST_COV],
			(P_LEVEL3) AS [COST_GAP],
			(P_LEVEL4) AS [COST_CAT],
			(P_LEVEL_P1+P_LEVEL_P2+P_LEVEL_P3+P_LEVEL_P4) AS [COPAY_TOT],
			(P_LEVEL1+P_LEVEL2+P_LEVEL3+P_LEVEL4) AS [COST_TOTAL],
			(C.LICS) AS PBM_LICS,
			''0.00'' AS LICS_FAKE,
			ADJUSTMENT_DELETE_CODE'
	SET @pSQL = @pSQL + '
				FROM dbo.RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA A
			JOIN RX_CLAIMS B ON A.CLAIM_ID = B.CLAM_ID --AND A.PDE_SEQ = B.PDE_SEQ
			LEFT JOIN RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA_GAP C ON A.CLAIM_ID = C.CLAM_ID AND A.PDE_SEQ = C.PDE_SEQ
			JOIN MB_ENROLLEE_INFO D ON B.RX_MEME_ID = D.MEMBER_ID
			LEFT JOIN RX_NDC_DRUGS E ON B.DRUG_NDC_CODE = E.DRUG_NDC_CODE
				WHERE ' + @pWhereCondition + '
				order by CLAM_ORIGINAL_ENTRY_DATE'

	PRINT @pSQL

	EXEC sp_executesql @pSQL
		,N'@pDyanmicStatusVariable nvarchar(75)'
		,@pDyanmicStatusVariable = @pPdeStatus
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

PRINT N'Altering [dbo].[PDE_FIR_REC_DETAILS]'
GO

-- PDE_FIR_REC_DETAILS @pAccuYear ='2015', @pMonth ='2', @pFirStatus = 'In'
ALTER PROCEDURE [dbo].[PDE_FIR_REC_DETAILS] (
	@pAccuYear VARCHAR(4) = ''
	,@pFieldName VARCHAR(50) = ''
	,@pFirStatus VARCHAR(10) = ''
	,@pMonth VARCHAR(2) = ''
	,@pMemberID VARCHAR(25) = ''
	,@pClaimID VARCHAR(25) = ''
	,@pProductID NVARCHAR(10) = NULL
	,@pDataLimit NVARCHAR(10) = ''
	,@pOffSet NVARCHAR(10) = ''
	,@pSQL NVARCHAR(max) = '' OUTPUT
	)
AS
BEGIN
	DECLARE @pWhereCondition VARCHAR(4000) = ''
		,@OffsetText NVARCHAR(1000) = ''
		,@TransferInOrOut VARCHAR(10) = CASE 
			WHEN @pFirStatus = 'In'
				THEN 'F2'
			ELSE 'F1'
			END
	--select plan id's
	DECLARE @planID VARCHAR(8000)

	SET @planID = 'X0001'

	--select plan id's
	SELECT @planID = COALESCE(@planID + ''',''', '') + CODE
	FROM SUP_SUPPORT_CODE
	WHERE CODE_TYPE = 'PLAN_ID'
		AND CODE IS NOT NULL

	DECLARE @Outstanding VARCHAR(2500) = '( t.MEMBER_CK is null and (e.PRE_AFTER_PLAN_ID NOT IN (''' + @planID + ''') and (e.PRE_AFTER_PLAN_ID  is NOT null and e.PRE_AFTER_PLAN_ID <> '''')) )'
		,@Received VARCHAR(2500) = '(t.TRANSACTION_CODE = ''' + @TransferInOrOut + '''' + ' AND YEAR(t.TERMINATION_DATE) = ''' + @pAccuYear + '''' + ')'
		,@Required VARCHAR(2500) = '(( t.MEMBER_CK is null and (e.PRE_AFTER_PLAN_ID NOT IN (''' + @planID + ''') and (e.PRE_AFTER_PLAN_ID  is NOT null and e.PRE_AFTER_PLAN_ID <> '''')) ) OR (t.TRANSACTION_CODE = ''' + @TransferInOrOut + '''  ))'
		,@Errors VARCHAR(2500) = ' (t.FIR_APPLIED_TO_CLAIM = ''F'' )'

	--Set default values
	IF @pAccuYear IS NULL
		OR @pAccuYear = ''
		SET @pAccuYear = YEAR(GETDATE())

	IF @pFirStatus IS NULL
		OR @pFirStatus = ''
		SET @pFirStatus = 'In'

	IF @pFieldName IS NULL
		OR @pFieldName = ''
		SET @pFieldName = 'REQUIRED_FIR'
	-- build where condition
	SET @pWhereCondition = CASE 
			WHEN @pFirStatus = 'In'
				THEN ' TRANSACTION_TYPE in (''NE'',''RI'') AND TRANSACTION_VOID_IND=''N'' '
			WHEN @pFirStatus = 'Out'
				THEN ' TRANSACTION_TYPE=''TM'' AND TRANSACTION_VOID_IND=''N'''
			END
	SET @pWhereCondition = @pWhereCondition + ' AND YEAR(e.PRODUCT_EFF_DATE) = ''' + @pAccuYear + ''' ' + ' and (e.PRE_AFTER_PLAN_ID NOT IN (''' + @planID + '''' + ') or e.PRE_AFTER_PLAN_ID is null or e.PRE_AFTER_PLAN_ID  = '''') '

	IF @pMonth <> ''
		SET @pWhereCondition = @pWhereCondition + ' AND MONTH(e.PRODUCT_EFF_DATE) = ''' + @pMonth + ''' '

	-- Setting offset
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

	SET @pWhereCondition = @pWhereCondition + ' AND ' + CASE 
			WHEN @pFieldName = 'RECEIVED_FIR'
				AND @pFirStatus = 'In'
				THEN @Received
			WHEN @pFieldName = 'REQUIRED_FIR'
				AND @pFirStatus = 'In'
				THEN @Required
			WHEN @pFieldName = 'RECEIVED_FIR'
				AND @pFirStatus = 'Out'
				THEN @Received
			WHEN @pFieldName = 'REQUIRED_FIR'
				AND @pFirStatus = 'Out'
				THEN @Required
			WHEN @pFieldName = 'OUTSTANDING_FIR'
				THEN @Outstanding
			WHEN @pFieldName = 'ENROLLEMENT'
				THEN ' m.MEMBER_ID IS NOT NULL '
			WHEN @pFieldName = 'TROOP'
				THEN ' t.APPLIED_TROOP_AMOUNT  IS NOT NULL '
			WHEN @pFieldName = 'COST'
				THEN ' t.APPLIED_DRUG_COST IS NOT NULL'
			WHEN @pFieldName = 'ERRORS'
				THEN @Errors
			END
	-- build select statement
	SET @pSQL = 'SELECT m.MEMBER_ID AS ID_NUMBER,' + CASE 
			WHEN @pFirStatus = 'Out'
				THEN 'CASE WHEN e.TRANSACTION_REASON=''Deceased'' THEN ''Deceased'' ELSE CASE WHEN STATUS IS NULL THEN ''No FIR Transfer Out'' ELSE ''FIR Sent'' END END AS STATUS,'
			WHEN @pFirStatus = 'In'
				THEN 'CASE WHEN STATUS IS NULL THEN ''No FIR Transfer In'' ELSE ''FIR Received'' END AS STATUS,'
			END + CASE 
			WHEN @pFirStatus = 'Out'
				THEN 'PRODUCT_EFF_DATE AS ENROLLMENT_ACTION_DATE,'
			WHEN @pFirStatus = 'In'
				THEN 'ENROLLMENT_ACTION_DATE,'
			END + 't.TRANSACTION_DATE,
	f.CONTRACT_ID,
	CONTRACT_NAME,
	AMOUNT_APPLIED_TO_CLAIM,
	 t.FIR_APPLIED_TO_CLAIM,
	t.DRUG_COST AS DRUG_COST,
	e.PLAN_ID,
	t.CONTRACT_ID,
	 t.TROOP_AMOUNT AS TROOP_AMOUNT
	 from MB_MEMBER_PRODUCTS e
	left join RX_BALANCE_TRANSFER t on e.MEMBER_CK = t.MEMBER_CK AND YEAR(t.TERMINATION_DATE) = ''' + @pAccuYear + ''' and e.PLAN_ID = t.PLAN_ID and t.TRANSACTION_CODE = ''' + @TransferInOrOut + ''' 
		RIGHT JOIN MB_ENROLLEE_INFO m ON e.MEMBER_CK=m.MEMBER_CK
    left join [SUP_P2P_PLAN_NAME] f ON t.CONTRACT_ID = f.CONTRACT_ID
    WHERE ' + @pWhereCondition + ' ORDER BY YEAR(e.PRODUCT_EFF_DATE), MONTH(e.PRODUCT_EFF_DATE), m.MEMBER_ID' + @OffsetText

	PRINT @pSQL

	EXEC sp_executesql @pSQL
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

PRINT N'Altering [dbo].[PHAR_FORM_TRACKER_ADD_DRUG_NDC_TITLE]'
GO

ALTER PROCEDURE [dbo].[PHAR_FORM_TRACKER_ADD_DRUG_NDC_TITLE] @pNDC VARCHAR(15) = ''
	,@pFormularyName NVARCHAR(50) = ''
	,@pFormularyYear NVARCHAR(4) = ''
	,@pGPILength INT = ''
	,@pCategoryName NVARCHAR(510) = ''
	,--Parameter not currently used, but required to make page refresh correctly
	@pClassName NVARCHAR(510) = ''
	,--Parameter not currently used, but required to make page refresh correctly
	@pTime NVARCHAR(100) = '' --Parameter not currently used, but required to make page refresh correctly
AS
BEGIN
	DECLARE @WhereCondition VARCHAR(2500) = ''
		,@GPICount NVARCHAR(10) = ''
		,@GPI NVARCHAR(14) = ''
		,@SQL NVARCHAR(MAX) = ''
		,@NDCBlankFlag NVARCHAR(1) = 'N'

	--set default values
	IF @pGPILength IS NULL
		OR @pGPILength = ''
		SET @pGPILength = 14

	IF @pFormularyYear IS NULL
		OR @pFormularyYear = ''
	BEGIN
		SELECT @pFormularyYear = (
				SELECT TOP 1 FRF_YEAR
				FROM PLAN_HPMS_FORMULARY_SUBMISSIONS
				WHERE FORMULARY_ID IS NOT NULL
					AND FRF_YEAR IS NOT NULL
				ORDER BY FRF_YEAR DESC
					,FORMULARY_ID
				)
	END

	--Set default formulary name
	IF (
			@pFormularyName = ''
			OR @pFormularyName IS NULL
			)
	BEGIN
		SELECT @pFormularyName = (
				SELECT TOP 1 FORMULARY_ID
				FROM PLAN_HPMS_FORMULARY_SUBMISSIONS A
				LEFT JOIN SUP_SUPPORT_CODE B ON A.FORMULARY_ID = B.CODE
				WHERE FORMULARY_ID IS NOT NULL
					AND FRF_YEAR = @pFormularyYear
					AND CODE_TYPE = 'DRUGFORMULARY'
				ORDER BY CODE_SUMMARY
				)
	END

	--set this flag for page load to send back a Yes value to allow DIV to be loaded
	IF @pNDC IS NULL
		OR @pNDC = ''
		SET @NDCBlankFlag = 'Y'

	IF @pNDC IS NULL
		OR @pNDC = ''
		SET @pNDC = '00378801593'

	--Get GPI for specified NDC
	SELECT @GPI = GNPR_ID
	FROM dbo.RX_NDC_DRUGS
	WHERE DRUG_NDC_CODE = @pNDC

	--truncate GPI to appropriate length
	SET @GPI = LEFT(@GPI, @pGPILength)

	--Get count of drugs with matching GPI
	SELECT @GPICount = COUNT(*)
	FROM dbo.RX_NDC_DRUGS
	WHERE GNPR_ID LIKE @GPI + '%'

	PRINT @GPICount

	--build where condition
	SET @WhereCondition = ' DRUGS.DRUG_NDC_CODE = ''' + @pNDC + ''' '
	--build select statement
	SET @SQL = 'SELECT TOP 1 
		CASE WHEN FRF.FORMULARY_ID IS NULL OR FRF_ACTION LIKE''DEL%'' THEN ''NO'' ELSE ''YES'' END AS COVERED 
	           ,(SELECT CASE WHEN FRF.FORMULARY_ID = ''PARTD'' OR ''' + @NDCBlankFlag + ''' = ''Y'' THEN ''YES'' ELSE ''NO'' END AS PART_D_COVERED 
		FROM RX_NDC_DRUGS DRUGS 
			left JOIN PLAN_DRUG_FORMULARY PLAN_FORM ON DRUGS.GNPR_ID LIKE '''' + PLAN_FORM.GPI_10_ID + ''%'' + '''' AND DRUGS.DRUG_FORM = PLAN_FORM.DRUG_FORM
						AND DRUGS.DRUG_ROUTE = PLAN_FORM.DRUG_ROUTE AND DRUGS.DRUG_OTC_FLAG = PLAN_FORM.DRUG_OTC_FLAG AND DRUGS.DRUG_GENERIC_FLAG = PLAN_FORM.DRUG_GENERIC_FLAG 
						AND PLAN_FORM.FORMULARY_ID = ''PARTD''  AND YEAR(EFFECTIVE_DATE) = ''' + @pFormularyYear + '''
			LEFT OUTER JOIN PLAN_HPMS_FORMULARY_SUBMISSIONS FRF ON PLAN_FORM.THERAPEUTIC_CATEGORY_NAME = FRF.THERAPEUTIC_CATEGORY_NAME AND FRF.FORMULARY_ID = ''PARTD'' AND
						PLAN_FORM.THERAPEUTIC_CLASS_NAME = FRF.THERAPEUTIC_CLASS_NAME AND PLAN_FORM.RELATED_NDC = FRF.RELATED_NDC AND FRF_YEAR = ''' + 
		@pFormularyYear + '''
			LEFT JOIN (SELECT CODE,CODE_DESC,CODE_TYPE_DESC AS DRUG_ROUTE_LABEL FROM SUP_SUPPORT_CODE WHERE CODE_TYPE = ''DRUG_FORM'') C ON DRUGS.DRUG_FORM = CODE AND DRUGS.DRUG_ROUTE = CODE_DESC
			WHERE' + @WhereCondition + ') AS PART_D_COVERED '
	SET @SQL = @SQL + '
		,(SELECT CASE WHEN FRF.FORMULARY_ID = ''SPECD'' OR ''' + @NDCBlankFlag + ''' = ''Y'' THEN ''YES'' ELSE ''NO'' END AS PART_D_COVERED 
		FROM RX_NDC_DRUGS DRUGS 
			left JOIN PLAN_DRUG_FORMULARY PLAN_FORM ON DRUGS.GNPR_ID LIKE '''' + PLAN_FORM.GPI_10_ID + ''%'' + '''' AND DRUGS.DRUG_FORM = PLAN_FORM.DRUG_FORM
						AND DRUGS.DRUG_ROUTE = PLAN_FORM.DRUG_ROUTE AND DRUGS.DRUG_OTC_FLAG = PLAN_FORM.DRUG_OTC_FLAG AND DRUGS.DRUG_GENERIC_FLAG = PLAN_FORM.DRUG_GENERIC_FLAG 
						AND PLAN_FORM.FORMULARY_ID = ''SPECD''  AND YEAR(EFFECTIVE_DATE) = ''' + @pFormularyYear + '''
			LEFT OUTER JOIN PLAN_HPMS_FORMULARY_SUBMISSIONS FRF ON PLAN_FORM.THERAPEUTIC_CATEGORY_NAME = FRF.THERAPEUTIC_CATEGORY_NAME AND FRF.FORMULARY_ID = ''SPECD'' AND
						PLAN_FORM.THERAPEUTIC_CLASS_NAME = FRF.THERAPEUTIC_CLASS_NAME AND PLAN_FORM.RELATED_NDC = FRF.RELATED_NDC AND FRF_YEAR = ''' + @pFormularyYear + 
		'''
			LEFT JOIN (SELECT CODE,CODE_DESC,CODE_TYPE_DESC AS DRUG_ROUTE_LABEL FROM SUP_SUPPORT_CODE WHERE CODE_TYPE = ''DRUG_FORM'') C ON DRUGS.DRUG_FORM = CODE AND DRUGS.DRUG_ROUTE = CODE_DESC
			WHERE' + @WhereCondition + ') AS SPECD_COVERED '
	SET @SQL = @SQL + '
		,(SELECT CASE WHEN FRF.FORMULARY_ID = ''PROTD'' OR ''' + @NDCBlankFlag + ''' = ''Y'' THEN ''YES'' ELSE ''NO'' END AS PROTD_COVERED 
		FROM RX_NDC_DRUGS DRUGS 
			left JOIN PLAN_DRUG_FORMULARY PLAN_FORM ON DRUGS.GNPR_ID LIKE '''' + PLAN_FORM.GPI_10_ID + ''%'' + '''' AND DRUGS.DRUG_FORM = PLAN_FORM.DRUG_FORM
						AND DRUGS.DRUG_ROUTE = PLAN_FORM.DRUG_ROUTE AND DRUGS.DRUG_OTC_FLAG = PLAN_FORM.DRUG_OTC_FLAG AND DRUGS.DRUG_GENERIC_FLAG = PLAN_FORM.DRUG_GENERIC_FLAG 
						AND PLAN_FORM.FORMULARY_ID = ''PROTD''  AND YEAR(EFFECTIVE_DATE) = ''' + @pFormularyYear + '''
			LEFT OUTER JOIN PLAN_HPMS_FORMULARY_SUBMISSIONS FRF ON PLAN_FORM.THERAPEUTIC_CATEGORY_NAME = FRF.THERAPEUTIC_CATEGORY_NAME AND FRF.FORMULARY_ID = ''PROTD'' AND
						PLAN_FORM.THERAPEUTIC_CLASS_NAME = FRF.THERAPEUTIC_CLASS_NAME AND PLAN_FORM.RELATED_NDC = FRF.RELATED_NDC AND FRF_YEAR = ''' + @pFormularyYear + 
		'''
			LEFT JOIN (SELECT CODE,CODE_DESC,CODE_TYPE_DESC AS DRUG_ROUTE_LABEL FROM SUP_SUPPORT_CODE WHERE CODE_TYPE = ''DRUG_FORM'') C ON DRUGS.DRUG_FORM = CODE AND DRUGS.DRUG_ROUTE = CODE_DESC
			WHERE' + @WhereCondition + ') AS PROTD_COVERED '
	SET @SQL = @SQL + '
	FROM RX_NDC_DRUGS DRUGS 
	left JOIN PLAN_DRUG_FORMULARY PLAN_FORM ON DRUGS.GNPR_ID LIKE '''' + PLAN_FORM.GPI_10_ID + ''%'' + '''' AND DRUGS.DRUG_FORM = PLAN_FORM.DRUG_FORM
				AND DRUGS.DRUG_ROUTE = PLAN_FORM.DRUG_ROUTE AND DRUGS.DRUG_OTC_FLAG = PLAN_FORM.DRUG_OTC_FLAG AND DRUGS.DRUG_GENERIC_FLAG = PLAN_FORM.DRUG_GENERIC_FLAG 
				AND PLAN_FORM.FORMULARY_ID = ''' + @pFormularyName + '''  AND YEAR(EFFECTIVE_DATE) = ''' + @pFormularyYear + '''
	LEFT OUTER JOIN PLAN_HPMS_FORMULARY_SUBMISSIONS FRF ON PLAN_FORM.THERAPEUTIC_CATEGORY_NAME = FRF.THERAPEUTIC_CATEGORY_NAME AND FRF.FORMULARY_ID = ''' + @pFormularyName + ''' AND
				PLAN_FORM.THERAPEUTIC_CLASS_NAME = FRF.THERAPEUTIC_CLASS_NAME AND PLAN_FORM.RELATED_NDC = FRF.RELATED_NDC AND FRF_YEAR = ''' + @pFormularyYear + '''
	LEFT JOIN (SELECT CODE,CODE_DESC,CODE_TYPE_DESC AS DRUG_ROUTE_LABEL FROM SUP_SUPPORT_CODE WHERE CODE_TYPE = ''DRUG_FORM'') C ON DRUGS.DRUG_FORM = CODE AND DRUGS.DRUG_ROUTE = CODE_DESC
	WHERE' + @WhereCondition + 
		' 
	ORDER BY FRF.EFFECTIVE_DATE DESC'

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

PRINT N'Altering [dbo].[PHAR_FORM_TRACKER_ADD_DRUG_INSERT]'
GO

ALTER PROCEDURE [dbo].[PHAR_FORM_TRACKER_ADD_DRUG_INSERT] @pNDC VARCHAR(20)
	,@pFormularyYear VARCHAR(8)
	,@pFRFAction VARCHAR(15)
	,@pEffectiveDate DATE
	,@pFormularyName VARCHAR(10)
	,@pPBP VARCHAR(6)
	,@pTier VARCHAR(4)
	,@pQuantityLimit VARCHAR(15) = ''
	,@pQuantityLimitDays INT
	,@pPA VARCHAR(2)
	,@pPADesc VARCHAR(200)
	,@pTherapeuticCategory VARCHAR(510)
	,@pTherapeuticClass VARCHAR(510)
	,@pStepTherapyType NVARCHAR(2)
	,@pStepTherapyGroupDesc VARCHAR(200)
	,@pStepTherapyStepValue VARCHAR(4) = ''
	,@pUpdatePerson VARCHAR(100)
	,@pGPILength INT
	,@pUpdateTime DATETIME
	,@ErrorMessage VARCHAR(255) = '' OUTPUT
	,@pFormularyType VARCHAR(10)
AS
SET NOCOUNT ON

DECLARE @GPI VARCHAR(14)
	,@FormularyID VARCHAR(12)
	,@FindRelatedNDC VARCHAR(20)
	--,@pStepTherapyGroupDesc VARCHAR(200)
	--,@pFormularyType        VARCHAR(10)
	,@Quantity DECIMAL(15, 5)

--Verify that NDC code exists
IF NOT EXISTS (
		SELECT 1
		FROM dbo.RX_NDC_DRUGS
		WHERE DRUG_NDC_CODE = @pNDC
		)
BEGIN
	SET @ErrorMessage = 'The NDC code is not valid.'

	RETURN
END

--GET GPI from NDC, (gSearchValue is not defined) and get Formulary ID from SUP_SUPPORT_CODE
SET @GPI = (
		SELECT GNPR_ID
		FROM RX_NDC_DRUGS
		WHERE DRUG_NDC_CODE = @pNDC
		)
SET @FormularyID = (
		SELECT CODE_SUMMARY
		FROM SUP_SUPPORT_CODE
		WHERE CODE_TYPE = 'DRUGFORMULARY'
			AND CODE = @pFormularyName
		)
--Convert quantity limit from string to decimal
SET @Quantity = @pQuantityLimit

IF @Quantity = 0
	AND @pQuantityLimitDays = 0
BEGIN
	SET @Quantity = NULL
	SET @pQuantityLimitDays = NULL
END

--Replace -- with empty
IF @pPADesc = '--'
	OR @pPADesc = '---'
	SET @pPADesc = ''

IF @pTier = '--'
	OR @pTier = '---'
	SET @pTier = ''

--IF @pDrugTypeLabel = '--' OR @pDrugTypeLabel = '---' SET @pDrugTypeLabel = '' 
--IF @pQuantityLimit = '--' SET @pQuantityLimit = '' 
--IF @pQuantityLimitDays = '--' SET @pQuantityLimitDays = '' 
IF @pStepTherapyType = '--'
	OR @pStepTherapyType = '---'
	SET @pStepTherapyType = ''

--IF @pStepTherapyTotalGroups  = '--' SET @pStepTherapyTotalGroups  = '' 
IF @pStepTherapyStepValue = '--'
	OR @pStepTherapyStepValue = '---'
	SET @pStepTherapyStepValue = ''

IF @pStepTherapyGroupDesc = '--'
	OR @pStepTherapyGroupDesc = '---'
	SET @pStepTherapyGroupDesc = ''
--check to see if passed NDC is an expansion of related NDC, if is, replace passed NDC with correct related NDC
SET @FindRelatedNDC = (
		SELECT TOP 1 FRF.RELATED_NDC
		FROM RX_NDC_DRUGS DRUGS
		LEFT JOIN PLAN_DRUG_FORMULARY PLAN_FORM ON DRUGS.GNPR_ID LIKE '' + PLAN_FORM.GPI_10_ID + '%' + ''
			AND DRUGS.DRUG_FORM = PLAN_FORM.DRUG_FORM
			AND DRUGS.DRUG_ROUTE = PLAN_FORM.DRUG_ROUTE
			AND DRUGS.DRUG_OTC_FLAG = PLAN_FORM.DRUG_OTC_FLAG
			AND DRUGS.DRUG_GENERIC_FLAG = PLAN_FORM.DRUG_GENERIC_FLAG
			AND PLAN_FORM.FORMULARY_ID = @FormularyID
			AND YEAR(EFFECTIVE_DATE) = @pFormularyYear
		LEFT JOIN PLAN_HPMS_FORMULARY_SUBMISSIONS FRF ON PLAN_FORM.THERAPEUTIC_CATEGORY_NAME = FRF.THERAPEUTIC_CATEGORY_NAME
			AND PLAN_FORM.FORMULARY_ID = FRF.FORMULARY_ID
			AND PLAN_FORM.THERAPEUTIC_CLASS_NAME = FRF.THERAPEUTIC_CLASS_NAME
			AND PLAN_FORM.RELATED_NDC = FRF.RELATED_NDC
			AND FRF_YEAR = @pFormularyYear
		LEFT JOIN (
			SELECT CODE
				,CODE_DESC
				,CODE_TYPE_DESC AS DRUG_ROUTE_LABEL
			FROM SUP_SUPPORT_CODE
			WHERE CODE_TYPE = 'DRUG_FORM'
			) C ON DRUGS.DRUG_FORM = CODE
			AND DRUGS.DRUG_ROUTE = CODE_DESC
		WHERE DRUGS.DRUG_NDC_CODE = @pNDC
			AND FRF_YEAR = @pFormularyYear
		)

IF NOT (
		@FindRelatedNDC IS NULL
		OR @FindRelatedNDC = ''
		)
	SET @pNDC = @FindRelatedNDC

PRINT @pNDC

--If row already exists, do not insert
IF EXISTS (
		SELECT *
		FROM dbo.PLAN_HPMS_FORMULARY_SUBMISSIONS
		WHERE ISNULL(GPI, '') = ISNULL(@GPI, '') --new
			AND ISNULL(SUBMITED_ON_DATE, '') = ISNULL(CAST(@pUpdateTime AS DATE), '')
			AND ISNULL(PLAN_ID, '') = ISNULL(@pFormularyName, '')
			AND ISNULL(PBP, '') = ISNULL(@pPBP, '') --new
			AND ISNULL(TIER_LEVEL, '') = ISNULL(@pTier, '')
			AND ISNULL(QUANTITY_LIMIT_AMOUNT, 0) = ISNULL(@pQuantityLimit, 0)
			AND ISNULL(QUANTITY_LIMIT_DAYS, 0) = ISNULL(@pQuantityLimitDays, 0)
			AND ISNULL(PRIOR_AUTHORIZATION_TYPE, '') = ISNULL(@pPA, '')
			AND ISNULL(PRIOR_AUTHORIZATION_GROUP_DESC, '') = ISNULL(@pPADesc, '')
			AND ISNULL(THERAPEUTIC_CLASS_NAME, '') = ISNULL(@pTherapeuticClass, '')
			AND ISNULL(THERAPEUTIC_CATEGORY_NAME, '') = ISNULL(@pTherapeuticCategory, '')
			AND ISNULL(STEP_THERAPY_TYPE, '') = ISNULL(@pStepTherapyType, '')
			AND ISNULL(STEP_THERAPY_GROUP_DESC, '') = ISNULL(@pStepTherapyGroupDesc, '')
			AND ISNULL(STEP_THERAPY_STEP_VALUE, '') = ISNULL(@pStepTherapyStepValue, '')
			AND ISNULL(RELATED_NDC, '') = ISNULL(@pNDC, '') --new
			AND ISNULL(FORMULARY_TYPE, '') = ISNULL(@pFormularyType, '') --new
		)
BEGIN
	SET @ErrorMessage = 'Submission already exists.'

	RETURN
END
ELSE
BEGIN TRY
	PRINT ('INSERT STATEMENT')

	BEGIN TRANSACTION

	--Insert into formulary submissions
	INSERT INTO dbo.PLAN_HPMS_FORMULARY_SUBMISSIONS (
		FRF_YEAR
		,FRF_VERSION
		,FRF_ACTION
		,SUBMITED_ON_DATE
		,APPROVED_ON_DATE
		,EFFECTIVE_DATE
		,PLAN_ID
		,PBP
		,RXCUI
		,TIER_LEVEL
		--,DRUG_TYPE_LABEL
		--,QUANTITY_LIMIT_YN
		,QUANTITY_LIMIT_AMOUNT
		,QUANTITY_LIMIT_DAYS
		,PRIOR_AUTHORIZATION_TYPE
		,PRIOR_AUTHORIZATION_GROUP_DESC
		--,LIMITED_ACCESS_YN
		,THERAPEUTIC_CATEGORY_NAME
		,THERAPEUTIC_CLASS_NAME
		,STEP_THERAPY_TYPE
		--,STEP_THERAPY_TOTAL_GROUPS
		,STEP_THERAPY_GROUP_DESC
		,STEP_THERAPY_STEP_VALUE
		,RELATED_NDC
		,GPI
		,FORMULARY_ID
		,GPI_10_ID
		,UPDATE_PERSON
		,UPDATE_TIME
		,FORMULARY_TYPE
		)
	SELECT @pFormularyYear --FRF_YEAR
		,CONVERT(CHAR(8), @pUpdateTime, 112) --FRF_VERSION
		,UPPER(@pFRFAction) --FRF_ACTION
		,@pUpdateTime --SUBMITTED_ON_DATE
		,@pUpdateTime --APPROVED_ON_DATE
		,@pEffectiveDate --EFFECTIVE_DATE
		,@FormularyID --PLAN_ID
		,@pPBP --PBP
		,DRUG_LATEST_RXCUI --RXCUI
		,@pTier --TIER_LEVEL
		,@Quantity --QUANTITY_LIMIT_AMOUNT
		,@pQuantityLimitDays --QUANTITY_LIMIT_DAYS
		,@pPA --PRIOR_AUTHORIZATION_TYPE
		,@pPADesc --PRIOR_AUTHORIZATION_GROUP_DESC
		,@pTherapeuticCategory --THERAPEUTIC_CATEGORY_NAME
		,@pTherapeuticClass --THERAPEUTIC_CLASS_NAME
		,@pStepTherapyType --STEP_THERAPY_TYPE
		,@pStepTherapyGroupDesc --STEP_THERAPY_GROUP_DESC
		,@pStepTherapyStepValue --STEP_THERAPY_STEP_VALUE
		,@pNDC --RELATED_NDC
		,@GPI --GPI
		,@pFormularyName --FORMULARY_ID
		,LEFT(@GPI, @pGPILength) --GPI_10_ID
		,@pUpdatePerson --UPDATE_PERSON
		,@pUpdateTime --UPDATE_TIME
		,@pFormularyType --FORMULARY_TYPE
	FROM dbo.RX_NDC_DRUGS
	WHERE DRUG_NDC_CODE = @pNDC

	--Insert into formulary
	EXEC dbo.SUPSP_RX_PLAN_FORMULARY_UPDATES @DRUG_NDC_CODE = @pNDC
		,@Recreate_Data = NULL
		,@FRF_YAER = @pFormularyYear
		,@Version = NULL
		,@FORMULARY_ID = @pFormularyName

	COMMIT TRANSACTION
END TRY

BEGIN CATCH
	IF @@TRANCOUNT > 0
		ROLLBACK TRANSACTION

	SELECT @ErrorMessage = ERROR_MESSAGE()
END CATCH
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

PRINT N'Altering [dbo].[PHAR_FORM_TRACKER_DRUGS_EXPANDED_SUMMARY_DETAILS]'
GO

SET QUOTED_IDENTIFIER OFF
GO

ALTER PROCEDURE [dbo].[PHAR_FORM_TRACKER_DRUGS_EXPANDED_SUMMARY_DETAILS] (
	@pUtilYear VARCHAR(4) = ''
	,@pFormularyYear VARCHAR(4) = ''
	,@pFormularyName VARCHAR(50) = ''
	,@pClassName VARCHAR(max) = ''
	,@pCategoryName VARCHAR(max) = ''
	,@pRoute VARCHAR(20) = ''
	,@pBG VARCHAR(3) = ''
	,@pStep VARCHAR(2) = ''
	,@pPA VARCHAR(2) = ''
	,@pTier VARCHAR(2) = ''
	,@pDataLimit NVARCHAR(10) = ''
	,@pOffSet NVARCHAR(10) = ''
	,@pSQL NVARCHAR(MAX) = ''
	)
AS
BEGIN
	DECLARE @WhereNdcCondition VARCHAR(2500) = ''
		,@WhereClaimsCondition VARCHAR(2500) = ''
		,@pos INT
		,@ParsedPiece NVARCHAR(500)
		,@counter INT
		,@Class NVARCHAR(100)
		,@Category NVARCHAR(100)
		,@OffsetText NVARCHAR(1000) = ''

	IF @pUtilYear IS NULL
		OR @pUtilYear = ''
		SET @pUtilYear = YEAR(GETDATE())

	--set default values
	IF @pFormularyYear IS NULL
		OR @pFormularyYear = ''
	BEGIN
		SET @pFormularyYear = (
				SELECT TOP 1 FRF_YEAR
				FROM PLAN_HPMS_FORMULARY_SUBMISSIONS
				WHERE FORMULARY_ID IS NOT NULL
					AND FRF_YEAR IS NOT NULL
				ORDER BY FRF_YEAR DESC
					,FORMULARY_ID
				)
	END

	--Set default formulary name
	IF (
			@pFormularyName = ''
			OR @pFormularyName IS NULL
			)
	BEGIN
		SELECT @pFormularyName = (
				SELECT TOP 1 FORMULARY_ID
				FROM PLAN_HPMS_FORMULARY_SUBMISSIONS A
				LEFT JOIN SUP_SUPPORT_CODE B ON A.FORMULARY_ID = B.CODE
				WHERE FORMULARY_ID IS NOT NULL
					AND FRF_YEAR = @pFormularyYear
					AND CODE_TYPE = 'DRUGFORMULARY'
				ORDER BY CODE_SUMMARY
				)
	END

	--build where condition
	SET @WhereNdcCondition = ' FRF.FRF_YEAR = ''' + @pFormularyYear + '''  AND FRF.FORMULARY_ID = ''' + @pFormularyName + ''''

	IF @pClassName IS NULL
		OR @pClassName = ''
		SET @pClassName = 'Androgens'

	IF @pCategoryName IS NULL
		OR @pCategoryName = ''
		SET @pCategoryName = 'Hormonal Agents, Stimulant/ Replacement/ Modifying (Adrenal)'
	SET @WhereNdcCondition = @WhereNdcCondition + ' AND FRF.THERAPEUTIC_CATEGORY_NAME IN (''' + @pCategoryName + ''') AND FRF.THERAPEUTIC_CLASS_NAME IN (''' + @pClassName + ''')'
	--parse key value
	SET @WhereClaimsCondition = ' and YEAR(ACCUMULATOR_YEAR) = ''' + @pUtilYear + ''''

	--add filters
	IF NOT (@pRoute = '')
		SET @WhereNdcCondition = @WhereNdcCondition + ' AND DRUG_ROUTE_LABEL = ''' + @pRoute + ''''

	IF NOT (@pBG = '')
		SET @WhereNdcCondition = @WhereNdcCondition + ' AND DRUGS.DRUG_GENERIC_FLAG ' + CASE 
				WHEN @pBG = 'G'
					THEN '= ''Y'''
				ELSE + '<> ''Y'''
				END

	IF NOT (@pStep = '')
		SET @WhereNdcCondition = @WhereNdcCondition + ' AND ' + CASE 
				WHEN @pStep = '0'
					THEN '(PLAN_FORM.STEP_THERAPY_STEP_VALUE IS NULL OR PLAN_FORM.STEP_THERAPY_STEP_VALUE = '''' )'
				ELSE 'PLAN_FORMULARY.STEP_THERAPY_STEP_VALUE = ''' + @pStep + '''  '
				END

	IF NOT (@pPA = '')
		SET @WhereNdcCondition = @WhereNdcCondition + ' AND FRF.PRIOR_AUTHORIZATION_TYPE =''' + @pPA + ''''

	IF NOT (@pTier = '')
		SET @WhereNdcCondition = @WhereNdcCondition + ' AND FRF.TIER_LEVEL =''' + @pTier + ''''

	PRINT @WhereNdcCondition

	-- Setting offset and data limit
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

	--build select statement
	SET @pSQL = 'SELECT SUM(ISNULL(CLAIMS.ALLOWED_AMOUNT,0)) AS COST, SUM(ISNULL(CLAIMS.COPAY_AMOUNT,0))  AS COPAY
	,DRUG_LIST.DRUG_NDC_CODE as RELATED_NDC 
	,SUM(ISNULL(CLAIMS.RX_NUM,0))  AS RX_COUNT
	,MAX(DRUG_LIST.DRUG_NAME) AS DRUG_NAME
    , MAX(DRUG_FORM) AS DRUG_FORM, MAX(DRUG_ROUTE) AS DRUG_ROUTE
	, MAX(DRUG_GENERIC_FLAG) AS DRUG_GENERIC_FLAG,
	 DRUG_LIST.GNPR_ID
	
	FROM ANA_MONTHLY_ACCUMULATOR CLAIMS
	JOIN [dbo].[SUP_PRODUCT] PRODUCT ON CLAIMS.PDPD_ID = INTERNAL_PRODUCTS AND PLAN_ID = ''' + @pFormularyName + '''' + @WhereClaimsCondition + 
		'
	
	
	RIGHT JOIN (SELECT DISTINCT DRUGS.DRUG_NDC_CODE, DRUGS.DRUG_NAME, DRUGS.GNPR_ID, DRUGS.DRUG_FORM,DRUGS.DRUG_ROUTE, DRUGS.DRUG_GENERIC_FLAG
	FROM RX_NDC_DRUGS DRUGS 
	 JOIN PLAN_DRUG_FORMULARY PLAN_FORM ON DRUGS.GNPR_ID LIKE '''' + PLAN_FORM.GPI_10_ID + ''%'' + '''' AND DRUGS.DRUG_FORM = PLAN_FORM.DRUG_FORM
				AND DRUGS.DRUG_ROUTE = PLAN_FORM.DRUG_ROUTE AND DRUGS.DRUG_OTC_FLAG = PLAN_FORM.DRUG_OTC_FLAG AND DRUGS.DRUG_GENERIC_FLAG = PLAN_FORM.DRUG_GENERIC_FLAG 
				AND PLAN_FORM.FORMULARY_ID = ''' + @pFormularyName + '''  AND YEAR(EFFECTIVE_DATE) = ''' + @pFormularyYear + '''
	 JOIN PLAN_HPMS_FORMULARY_SUBMISSIONS FRF ON PLAN_FORM.THERAPEUTIC_CATEGORY_NAME = FRF.THERAPEUTIC_CATEGORY_NAME AND FRF.FORMULARY_ID = ''' + @pFormularyName + ''' AND
				PLAN_FORM.THERAPEUTIC_CLASS_NAME = FRF.THERAPEUTIC_CLASS_NAME AND PLAN_FORM.RELATED_NDC = FRF.RELATED_NDC AND FRF_YEAR = ''' + @pFormularyYear + 
		'''
	 JOIN (SELECT CODE,CODE_DESC,CODE_TYPE_DESC AS DRUG_ROUTE_LABEL FROM SUP_SUPPORT_CODE WHERE CODE_TYPE = ''DRUG_FORM'') C ON DRUGS.DRUG_FORM = CODE AND DRUGS.DRUG_ROUTE = CODE_DESC
	WHERE ' + @WhereNdcCondition + ') DRUG_LIST on CLAIMS.DRUG_NDC_CODE = DRUG_LIST.DRUG_NDC_CODE
	GROUP BY DRUG_LIST.DRUG_NDC_CODE, DRUG_LIST.GNPR_ID 
	ORDER BY DRUG_LIST.GNPR_ID' + @OffsetText

	PRINT @pSQL

	EXEC sp_executesql @pSQL
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

PRINT N'Altering [dbo].[PDE_FIR_POP_SUMMARY]'
GO

SET QUOTED_IDENTIFIER ON
GO

-- PDE_FIR_POP_SUMMARY @pMemberID=''
ALTER PROCEDURE [dbo].[PDE_FIR_POP_SUMMARY] (
	@pAccuYear VARCHAR(4) = ''
	,@pFieldName VARCHAR(50) = ''
	,@pFirStatus VARCHAR(10) = ''
	,@pMonth VARCHAR(2) = ''
	,@pMemberID VARCHAR(25) = ''
	,@pProductID NVARCHAR(10) = NULL
	,@pSQL NVARCHAR(max) = '' OUTPUT
	)
AS
BEGIN
	DECLARE @pWhereCondition VARCHAR(4000) = ''
		,@TransferInOrOut VARCHAR(10) = ''
	--select plan id's
	DECLARE @planID VARCHAR(8000)

	SELECT @planID = COALESCE(@planID + ''','' ', '') + CODE
	FROM SUP_SUPPORT_CODE
	WHERE CODE_TYPE = 'PLAN_ID'
		AND CODE IS NOT NULL

	--set default value
	SET @TransferInOrOut = CASE 
			WHEN @pFirStatus = 'In'
				THEN 'F2'
			ELSE 'F1'
			END

	DECLARE @Outstanding VARCHAR(2500) = '((ISNULL(t.TRANSACTION_CODE,'''') <> ''' + @TransferInOrOut + '''  and not (e.PRE_AFTER_PLAN_ID IS NULL OR e.PRE_AFTER_PLAN_ID = '''') )) '
		,@Received VARCHAR(2500) = '(t.TRANSACTION_CODE = ''' + @TransferInOrOut + '''' + ' AND YEAR(t.TERMINATION_DATE) = ''' + @pAccuYear + '''' + ')'
		,@Required VARCHAR(2500) = '(t.TRANSACTION_CODE = ''' + @TransferInOrOut + '''  OR (ISNULL(t.TRANSACTION_CODE,'''') = ''''   and not (e.PRE_AFTER_PLAN_ID IS NULL OR e.PRE_AFTER_PLAN_ID = '''') ))'
		,@Errors VARCHAR(2500) = ' (t.FIR_APPLIED_TO_CLAIM = ''F'' )'

	IF @pAccuYear IS NULL
		OR @pAccuYear = ''
		SET @pAccuYear = YEAR(GETDATE())

	IF @pFirStatus IS NULL
		OR @pFirStatus = ''
		SET @pFirStatus = 'In'

	IF @pFieldName IS NULL
		OR @pFieldName = ''
		SET @pFieldName = 'RECEIVED_FIR'

	IF @pMemberID IS NULL
		OR @pMemberID = ''
		SET @pMemberID = '20010900124700'
	SET @pWhereCondition = CASE 
			WHEN @pFirStatus = 'In'
				THEN ' TRANSACTION_TYPE in (''NE'',''RI'') AND TRANSACTION_VOID_IND=''N'' '
			WHEN @pFirStatus = 'Out'
				THEN ' TRANSACTION_TYPE=''TM'' AND TRANSACTION_VOID_IND=''N'''
			END
	SET @pWhereCondition = @pWhereCondition + ' AND YEAR(e.PRODUCT_EFF_DATE) = ''' + @pAccuYear + ''' ' + ' and (e.PRE_AFTER_PLAN_ID NOT IN (''' + @planID + '''' + ') or e.PRE_AFTER_PLAN_ID is null or e.PRE_AFTER_PLAN_ID  = '''') '
	SET @pWhereCondition = @pWhereCondition + ' AND ' + CASE 
			WHEN @pFieldName = 'RECEIVED_FIR'
				AND @pFirStatus = 'In'
				THEN @Received
			WHEN @pFieldName = 'REQUIRED_FIR'
				AND @pFirStatus = 'In'
				THEN @Required
			WHEN @pFieldName = 'RECEIVED_FIR'
				AND @pFirStatus = 'Out'
				THEN @Received
			WHEN @pFieldName = 'REQUIRED_FIR'
				AND @pFirStatus = 'Out'
				THEN @Required
			WHEN @pFieldName = 'OUTSTANDING_FIR'
				THEN @Outstanding
			WHEN @pFieldName = 'ENROLLEMENT'
				THEN ' m.MEMBER_ID IS NOT NULL '
			WHEN @pFieldName = 'TROOP'
				THEN ' t.APPLIED_TROOP_AMOUNT  IS NOT NULL '
			WHEN @pFieldName = 'COST'
				THEN ' t.APPLIED_DRUG_COST IS NOT NULL'
			WHEN @pFieldName = 'ERRORS'
				THEN @Errors
			END
	SET @pWhereCondition = @pWhereCondition + ' AND m.MEMBER_ID = ''' + @pMemberID + ''' '

	IF @pMonth <> ''
		SET @pWhereCondition = @pWhereCondition + ' AND MONTH(e.PRODUCT_EFF_DATE) = ''' + @pMonth + ''' '
	SET @pSQL = 'SELECT * FROM (SELECT DISTINCT m.MEMBER_ID AS MEMBER_ID,
	MEMBER_NAME,
	e.PLAN_ID as OWN_PLAN_ID,
	ISNULL(PRE_AFTER_PLAN_ID,''NA'') as OTHER_PLAN_ID,
	ISNULL(f.CONTRACT_NAME,''NA'') as PLAN_NAME,' + CASE 
			WHEN @pFirStatus = 'Out'
				THEN 'CASE WHEN e.TRANSACTION_REASON=''Deceased'' THEN ''Deceased'' ELSE CASE WHEN STATUS IS NULL THEN ''No FIR Transfer Out'' ELSE ''FIR Sent'' END END AS STATUS,'
			WHEN @pFirStatus = 'In'
				THEN 'CASE WHEN STATUS IS NULL THEN ''No FIR Transfer In'' ELSE ''FIR Received'' END AS STATUS,'
			END + CASE 
			WHEN @pFirStatus = 'Out'
				THEN 'PRODUCT_EFF_DATE AS PRODUCT_EFF_DATE,'
			WHEN @pFirStatus = 'In'
				THEN 'PRODUCT_EFF_DATE,'
			END + ' t.APPLIED_DRUG_COST AS COST,
	 t.AMOUNT_APPLIED_TO_CLAIM,
	t.CLAIM_COST_BEFORE_FIR,
	 t.APPLIED_TROOP_AMOUNT AS TROOP_AMOUNT,
	 t.FIR_APPLIED_TO_CLAIM,
	 t.TRANSACTION_DATE AS DATE_FIR_APPLIED
	from MB_MEMBER_PRODUCTS e
	left join RX_BALANCE_TRANSFER t on e.MEMBER_CK = t.MEMBER_CK AND YEAR(t.TERMINATION_DATE) = ''' + @pAccuYear + ''' and e.PLAN_ID = t.PLAN_ID and t.TRANSACTION_CODE = ''' + @TransferInOrOut + ''' 
    RIGHT JOIN MB_ENROLLEE_INFO m ON e.MEMBER_CK=m.MEMBER_CK
    left join [SUP_P2P_PLAN_NAME] f ON e.PRE_AFTER_PLAN_ID = f.CONTRACT_ID
    WHERE ' + @pWhereCondition + ' 
	) DATA
	ORDER BY YEAR(PRODUCT_EFF_DATE), MONTH(PRODUCT_EFF_DATE), MEMBER_ID'

	PRINT @pSQL

	EXEC sp_executesql @pSQL
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

PRINT N'Altering [dbo].[PDE_CMS_MEMBER_RECON_DETAILS_V2]'
GO

SET QUOTED_IDENTIFIER OFF
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[PDE_CMS_MEMBER_RECON_DETAILS_V2]
	-- Add the parameters for the stored procedure here
	@pACCU_YEAR NVARCHAR(4) = NULL
	,@pSTATUS VARCHAR(20) = NULL
	,@pNUM_MONTH VARCHAR(3) = NULL
	,@pProductID VARCHAR(10) = ''
	,@pFieldName VARCHAR(1000) = ''
	,@pDataLimit NVARCHAR(10) = ''
	,@pOffSet NVARCHAR(10) = ''
	,@pSQL NVARCHAR(4000) = '' OUTPUT
AS
BEGIN
	DECLARE @pDrug_Name NVARCHAR(50) = ''
	DECLARE @pPharmacy_Name NVARCHAR(50) = ''
	DECLARE @Condition VARCHAR(500) = ''
	DECLARE @StatusClause VARCHAR(50) = ''
	DECLARE @pLatest_Year VARCHAR(4)
	DECLARE @pLatest_Date DATETIME
		,@OffsetText NVARCHAR(1000) = ''
		,@WhereCondition NVARCHAR(max) = ''

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET QUOTED_IDENTIFIER OFF

	--IF (@pFieldName IS NULL or @pFieldName='' or @pFieldName='ALLOWED_AMOUNT') SET @pFieldName='INGREDIENT_COST_PAID + DISPENSING_FEE_PAID'
	--PRINT @pLatest_Year
	IF (
			@pACCU_YEAR IS NULL
			OR @pACCU_YEAR = ''
			)
		SET @pACCU_YEAR = YEAR(GETDATE())

	IF (
			@pSTATUS IS NULL
			OR @pSTATUS = ''
			)
		SET @pSTATUS = "C"
	ELSE
		SELECT @pSTATUS = CODE
		FROM SUP_SUPPORT_CODE
		WHERE CODE_DESC = @pSTATUS
			AND CODE_TYPE = 'PARTD_FLAG'

	PRINT @pSTATUS

	IF (
			@pProductID IS NULL
			OR @pProductID = ''
			)
		SET @pProductID = ''

	IF (
			@pNUM_MONTH IS NULL
			OR @pNUM_MONTH = ''
			OR LEN(@pNUM_MONTH) < 3
			)
	BEGIN
		SELECT TOP 1 @pLatest_Date = CREATED_ON
		FROM PDE_CMS_RETURN_SUMMARY
		WHERE SERVICE_YEAR = @pACCU_YEAR
		ORDER BY CREATED_ON DESC

		SET @Condition = 'CREATED_ON <=' + '''' + CONVERT(CHAR(10), @pLatest_Date, 101) + ''''
	END
	ELSE
	BEGIN
		SELECT TOP 1 @pLatest_Date = CREATED_ON
		FROM PDE_CMS_RETURN_SUMMARY
		WHERE SERVICE_YEAR = @pACCU_YEAR
			AND right(ltrim(rtrim(FILE_ID)), 3) = @pNUM_MONTH
		ORDER BY CREATED_ON DESC

		SET @Condition = 'CREATED_ON =' + '''' + CONVERT(CHAR(10), @pLatest_Date, 101) + ''''
	END

	SET @WhereCondition = 'WHERE SERVICE_YEAR =''' + @pACCU_YEAR + '''
			AND ' + @Condition + '
			AND DRUG_COVERAGE_STATUS_CODE =''' + @pStatus + ''' '

	IF @pFieldName IS NULL
		OR @pFieldname = ''
		SET @pFieldName = 'ALLOWED_AMOUNT'

	IF NOT (@pFieldName = 'ALLOWED_AMOUNT')
		SET @WhereCondition = @WhereCondition + ' AND ' + @pFieldName + ' <> 0'
	ELSE
		SET @WhereCondition = @WhereCondition + ' and NET_INGREDIENT_COST+NET_DISPENSING_FEE <> 0'

	-- Setting offset
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

	PRINT @WhereCondition

	-- ADJUSTMENT_DELETE_CODE='D'
	SET @pSQL = 
		'SELECT A.CARD_ID, MAX(CREATED_ON) AS CREATED_ON, DRUG_COVERAGE_STATUS_CODE, B.CODE_DESC , 
		SUM(RX_COUNT) AS RX_COUNT, SUM(NET_INGREDIENT_COST+NET_DISPENSING_FEE) as ALLOWED_AMOUNT, 
		SUM(NET_INGREDIENT_COST) AS NET_INGREDIENT_COST, SUM(NET_DISPENSING_FEE) AS NET_DISPENSING_FEE,
		SUM(NET_TOTAL_GROSS_DRUG_COST) AS NET_TOTAL_GROSS_DRUG_COST, SUM(NET_GDCB_AMOUNT) AS NET_GDCB_AMOUNT, 
		SUM(NET_GDCA_AMOUNT) AS NET_GDCA_AMOUNT, SUM(NET_PLRO_AMOUNT) AS NET_PLRO_AMOUNT,  
		SUM(NET_PATIENT_PAY_AMOUNT) AS NET_PATIENT_PAY_AMOUNT, SUM(NET_OTHER_TROOP_AMOUNT) AS NET_OTHER_TROOP_AMOUNT, 
		SUM(NET_LICS_AMOUNT) AS NET_LICS_AMOUNT, SUM(NET_TrOOP_AMOUNT) AS NET_TrOOP_AMOUNT, 
		SUM(NET_CPP_AMOUNT) AS NET_CPP_AMOUNT, SUM(NET_NPP_AMOUNT) AS NET_NPP_AMOUNT, 
		SUM(NUMBER_OF_ORIGINAL_PDES) AS NUMBER_OF_ORIGINAL_PDES, SUM(NUMBER_OF_ADJUSTED_PDES) AS NUMBER_OF_ADJUSTED_PDES, 
		SUM(NUMBER_OF_DELETION_PDES) AS NUMBER_OF_DELETION_PDES, SUM(NET_NUMBER_OF_CATASTROPHIC_COVERAGE_PDES) AS NET_NUMBER_OF_CATASTROPHIC_COVERAGE_PDES,
		SUM(NET_NUMBER_OF_ATTACHMENT_PDES) AS NET_NUMBER_OF_ATTACHMENT_PDES, SUM(NET_NUMBER_OF_NON_CATASTROPHIC_PDES) AS NET_NUMBER_OF_NON_CATASTROPHIC_PDES,
		BB.PDE_ALLOWED_AMOUNT, SUM((NET_INGREDIENT_COST+NET_DISPENSING_FEE)) - BB.PDE_ALLOWED_AMOUNT AS DIFF_ALLOWED_AMOUNT
		FROM dbo.PDE_CMS_RETURN_SUMMARY A
		join SUP_SUPPORT_CODE B on A.DRUG_COVERAGE_STATUS_CODE= B.CODE AND B.CODE_TYPE=''PARTD_FLAG''
		left join (select CARD_ID, SUM(CASE WHEN ADJUSTMENT_DELETE_CODE =''D'' THEN 0 - (INGREDIENT_COST_PAID + DISPENSING_FEE_PAID) ELSE (INGREDIENT_COST_PAID + DISPENSING_FEE_PAID) END) AS PDE_ALLOWED_AMOUNT
			from RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA B 
			JOIN RX_CLAIMS C ON B.CLAIM_ID=C.CLAM_ID AND B.PDE_SEQ=C.PDE_SEQ
			where YEAR(FILL_DT) = ''' 
		+ @pACCU_YEAR + ''' 
				AND BATCH_DATE <= ''' + convert(CHAR(10), @pLatest_Date, 101) + ''' and STATUS in (''ACC'',''INF'') 
			AND DRUG_COVERAGE_STATUS_CODE =''' + @pStatus + '''
			GROUP BY B.CARD_ID) BB ON A.CARD_ID = BB.CARD_ID
			' + @WhereCondition + '
		GROUP BY A.CARD_ID, DRUG_COVERAGE_STATUS_CODE, B.CODE_DESC, BB.PDE_ALLOWED_AMOUNT
		ORDER BY A.CARD_ID ' + @OffsetText

	PRINT @pSQL

	EXEC sp_sqlexec @pSQL
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

PRINT N'Altering [dbo].[PDE_PRS_DETAILS]'
GO

-- =============================================
-- Author:		Tiegang Cao
-- Create date: 11/16/2013
-- Description:	PDE PRS RECONCILIATION RISK
-- =============================================
ALTER PROCEDURE [dbo].[PDE_PRS_DETAILS]
	-- Add the parameters for the stored procedure here
	@pACCU_YEAR NVARCHAR(4) = NULL
	,@pSearchName NVARCHAR(50) = NULL
	,@pSearchType NVARCHAR(10) = NULL
	,@pProductID NVARCHAR(10) = ''
	,@pPBP NVARCHAR(100) = ''
	,@pPlanID NVARCHAR(100) = ''
	,@pFieldName NVARCHAR(50) = ''
	,@pDataLimit NVARCHAR(10) = ''
	,@pOffSet NVARCHAR(10) = ''
	,@pSQL NVARCHAR(MAX) = '' OUTPUT
AS
BEGIN
	DECLARE @pDrug_Name NVARCHAR(50) = ''
		,@OffsetText NVARCHAR(1000) = ''
	DECLARE @pPharmacy_Name NVARCHAR(50) = ''
		,@WhereCondition NVARCHAR(max) = ''

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET QUOTED_IDENTIFIER OFF

	IF (
			@pACCU_YEAR IS NULL
			OR @pACCU_YEAR = ''
			)
		SET @pACCU_YEAR = YEAR(GETDATE()) - 1

	IF @pFieldName IS NULL
		OR @pFieldName = ''
		SET @pFieldname = 'CADRE_TOT'

	IF (
			@pSearchType IS NOT NULL
			AND @pSearchName IS NOT NULL
			)
	BEGIN
		IF @pSearchType = 'DRUG'
			SET @pDrug_Name = @pSearchName

		IF @pSearchType = 'PHAR'
			SET @pPharmacy_Name = @pSearchName
	END

	SET @WhereCondition = ' WHERE PLAN_YEAR= ''' + @pACCU_YEAR + ''''

	-- set defaults for page load
	IF @pPlanID = ''
		OR @pPlanID IS NULL
		SELECT @pPlanID = (
				SELECT TOP 1 PLAN_ID
				FROM PDE_PRS_ANNUALLY_SUMMARY
				WHERE PLAN_ID IS NOT NULL
					AND PLAN_YEAR = @pACCU_YEAR
				ORDER BY PLAN_ID
				)

	IF (
			@pPBP = ''
			OR @pPBP IS NULL
			)
		SELECT @pPBP = (
				SELECT TOP 1 PBP
				FROM PDE_PRS_ANNUALLY_SUMMARY
				WHERE PBP IS NOT NULL
					AND PLAN_YEAR = @pACCU_YEAR
					AND PLAN_ID = @pPlanID
				ORDER BY PBP
				)

	SET @WhereCondition = @WhereCondition + ' AND PBP = ''' + @pPBP + ''''
	SET @WhereCondition = @WhereCondition + ' AND PLAN_ID = ''' + @pPlanID + ''''

	--Setting offset and data limit
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

	SET @pSQL = CASE 
			WHEN @pFieldName LIKE '%TOT'
				THEN '
	SELECT 
	''(1) Count Of Unique Members'' AS TEXT,
	CLAIMS.COUNT_OF_UNIQUE_MEMBERS AS CLAIMS,                                                                            
	CMS.COUNT_OF_UNIQUE_MEMBERS AS CMS,
	PDE.COUNT_OF_UNIQUE_MEMBERS AS PDE,
	CADRE.COUNT_OF_UNIQUE_MEMBERS AS CADRE  

	                                                                                    
		FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID' + 
					' UNION

SELECT 
''(2) Current Sharing LICS Adjustment'' AS TEXT, 
CLAIMS.CURRENT_SHARING_LICS_ADJUSTMENT AS CLAIMS,         
CMS.CURRENT_SHARING_LICS_ADJUSTMENT AS CMS,
PDE.CURRENT_SHARING_LICS_ADJUSTMENT AS PDE,
CADRE.CURRENT_SHARING_LICS_ADJUSTMENT AS CADRE  

		FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID' + 
					'
		UNION 
		SELECT 
		''(3) Current Reinsurance Subsidy Adjustment Amount'' AS TEXT,
		CLAIMS.CURRENT_REINSURANCE_SUBSIDY_ADJUSTMENT_AMOUNT AS CLAIMS,
		CMS.CURRENT_REINSURANCE_SUBSIDY_ADJUSTMENT_AMOUNT AS CMS,
		PDE.CURRENT_REINSURANCE_SUBSIDY_ADJUSTMENT_AMOUNT AS PDE,
CADRE.CURRENT_REINSURANCE_SUBSIDY_ADJUSTMENT_AMOUNT AS CADRE


FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID' + 
					'
		UNION
		SELECT 
		''(4) Current Risk Sharing Amount'' AS TEXT, 
		CLAIMS.CURRENT_RISK_SHARING_AMOUNT AS CLAIMS,
		CMS.CURRENT_RISK_SHARING_AMOUNT AS CMS,
		PDE.CURRENT_RISK_SHARING_AMOUNT AS PDE,
CADRE.CURRENT_RISK_SHARING_AMOUNT AS CADRE
FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID' + 
					'
UNION
 SELECT 
 ''(5) Current Adjustment Due To Payment Recon Amount (=[2]+[3]+[4] )'' AS TEXT,
 CLAIMS.CURRENT_ADJUSTMENT_DUE_TO_PAYMENT_RECON_AMOUNT AS CLAIMS, 
 CMS.CURRENT_ADJUSTMENT_DUE_TO_PAYMENT_RECON_AMOUNT AS CMS,
 PDE.CURRENT_ADJUSTMENT_DUE_TO_PAYMENT_RECON_AMOUNT AS PDE,
CADRE.CURRENT_ADJUSTMENT_DUE_TO_PAYMENT_RECON_AMOUNT AS CADRE  
FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID'
			WHEN @pFieldName LIKE '%LICS'
				THEN '
	SELECT 
	''(1) Actual LICS:'' AS TEXT,
	CLAIMS.CURRENT_ACTUAL_TOTAL_LICS_COST AS CLAIMS,                                                                            
	CMS.CURRENT_ACTUAL_TOTAL_LICS_COST AS CMS,
	PDE.CURRENT_ACTUAL_TOTAL_LICS_COST AS PDE,
	CADRE.CURRENT_ACTUAL_TOTAL_LICS_COST AS CADRE  

	                                                                                    
		FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + 
					'  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID' + ' UNION

SELECT 
''(2) Prospective LICS'' AS TEXT, 
CLAIMS.CURRENT_PROSPECTIVE_TOTAL_LICS_COST AS CLAIMS,         
CMS.CURRENT_PROSPECTIVE_TOTAL_LICS_COST AS CMS,
PDE.CURRENT_PROSPECTIVE_TOTAL_LICS_COST AS PDE,
CADRE.CURRENT_PROSPECTIVE_TOTAL_LICS_COST AS CADRE  

		FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID' + 
					'
		UNION 
		SELECT 
		''(3) Current Sharing LICS Adjustment (=[1] - [2] )'' AS TEXT,
		CLAIMS.CURRENT_SHARING_LICS_ADJUSTMENT AS CLAIMS,
		CMS.CURRENT_SHARING_LICS_ADJUSTMENT AS CMS,
		PDE.CURRENT_SHARING_LICS_ADJUSTMENT AS PDE,
CADRE.CURRENT_SHARING_LICS_ADJUSTMENT AS CADRE


FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID'
			WHEN @pFieldName LIKE '%REIN'
				THEN '
SELECT * FROM(
	SELECT 
	''(1) Total GDCA Amount'' AS TEXT,
	CAST(CLAIMS.TOTAL_GDCA_AMOUNT AS NVARCHAR) AS CLAIMS,                                                                            
	CAST(CMS.TOTAL_GDCA_AMOUNT AS NVARCHAR) AS CMS,
	CAST(PDE.TOTAL_GDCA_AMOUNT AS NVARCHAR) AS PDE,
	CAST(CADRE.TOTAL_GDCA_AMOUNT AS NVARCHAR) AS CADRE,
	''01'' AS SEQ  

	                                                                                    
		FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + 
					'  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID' + ' UNION

SELECT 
''(2) Total GDCB Amount'' AS TEXT, 
CAST(CLAIMS.TOTAL_GDCB_AMOUNT AS NVARCHAR) AS CLAIMS,         
CAST(CMS.TOTAL_GDCB_AMOUNT AS NVARCHAR) AS CMS,
CAST(PDE.TOTAL_GDCB_AMOUNT AS NVARCHAR) AS PDE,
CAST(CADRE.TOTAL_GDCB_AMOUNT AS NVARCHAR) AS CADRE,
	''02'' AS SEQ    

		FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + 
					'  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID' + '
		UNION 
		SELECT 
		''(3) Reinsurance DIR Ratio (= GDCA/(GDCB + GDCA) )'' AS TEXT,
		CAST(CLAIMS.REINSURANCE_DIR_RATIO AS NVARCHAR) +''**'' AS CLAIMS,
		CAST(CMS.REINSURANCE_DIR_RATIO AS NVARCHAR)+''**'' AS CMS,
		CAST(PDE.REINSURANCE_DIR_RATIO AS NVARCHAR)+''**'' AS PDE,
CAST(CADRE.REINSURANCE_DIR_RATIO AS NVARCHAR)+''**'' AS CADRE,
	''03'' AS SEQ    


FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + 
					'  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID' + '
		UNION
		SELECT 
		''(4) Reported Part D Covered DIR (Rebate Report To CMS)'' AS TEXT, 
		CAST(CLAIMS.REPORTED_PARTD_COVERED_DIR AS NVARCHAR) AS CLAIMS,
		CAST(CMS.REPORTED_PARTD_COVERED_DIR AS NVARCHAR) AS CMS,
		CAST(PDE.REPORTED_PARTD_COVERED_DIR AS NVARCHAR) AS PDE,
CAST(CADRE.REPORTED_PARTD_COVERED_DIR AS NVARCHAR) AS CADRE,
	''04'' AS SEQ    
FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + 
					'  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID' + '
UNION
 SELECT 
 ''(5) Total Estimated POS Rebate Amount'' AS TEXT,
 CAST(CLAIMS.TOTAL_ESTIMATED_POS_REBATE_AMOUNT AS NVARCHAR) AS CLAIMS, 
 CAST(CMS.TOTAL_ESTIMATED_POS_REBATE_AMOUNT AS NVARCHAR) AS CMS,
 CAST(PDE.TOTAL_ESTIMATED_POS_REBATE_AMOUNT AS NVARCHAR) AS PDE,
CAST(CADRE.TOTAL_ESTIMATED_POS_REBATE_AMOUNT AS NVARCHAR) AS CADRE ,
	''05'' AS SEQ     
FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + 
					'  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID' + ' UNION

SELECT 
''(6) Net Part D Covered DIR Amount (=[4] + [5] )'' AS TEXT, 
CAST(CLAIMS.NET_PARTD_COVERED_DIR_AMOUNT AS NVARCHAR) AS CLAIMS,         
CAST(CMS.NET_PARTD_COVERED_DIR_AMOUNT AS NVARCHAR) AS CMS,
CAST(PDE.NET_PARTD_COVERED_DIR_AMOUNT AS NVARCHAR) AS PDE,
CAST(CADRE.NET_PARTD_COVERED_DIR_AMOUNT AS NVARCHAR) AS CADRE  ,
	''06'' AS SEQ    

		FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + 
					'  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID' + '
		UNION 
		SELECT 
		''(7) Reinsurance Portion DIR Amount (=[6] * [3] )'' AS TEXT,
		CAST(CLAIMS.REINSURANCE_PORTION_DIR_AMOUNT AS NVARCHAR) AS CLAIMS,
		CAST(CMS.REINSURANCE_PORTION_DIR_AMOUNT AS NVARCHAR) AS CMS,
		CAST(PDE.REINSURANCE_PORTION_DIR_AMOUNT AS NVARCHAR) AS PDE,
CAST(CADRE.REINSURANCE_PORTION_DIR_AMOUNT AS NVARCHAR) AS CADRE,
	''07'' AS SEQ    


FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + 
					'  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID' + '
		UNION
		SELECT 
		''(8) Allowable Reinsurance Cost Amount (=[1] - [7])'' AS TEXT, 
		CAST(CLAIMS.ALLOWABLE_REINSURANCE_COST_AMOUNT AS NVARCHAR) AS CLAIMS,
		CAST(CMS.ALLOWABLE_REINSURANCE_COST_AMOUNT AS NVARCHAR) AS CMS,
		CAST(PDE.ALLOWABLE_REINSURANCE_COST_AMOUNT AS NVARCHAR) AS PDE,
CAST(CADRE.ALLOWABLE_REINSURANCE_COST_AMOUNT AS NVARCHAR) AS CADRE,
	''08'' AS SEQ    
FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + 
					'  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID' + '
UNION
 SELECT 
 ''(9) Current Actual Reinsurance Subsidy Amount (=[8] * 0.8 )'' AS TEXT,
 CAST(CLAIMS.CURRENT_ACTUAL_REINSURANCE_SUBSIDY_AMOUNT AS NVARCHAR) AS CLAIMS, 
 CAST(CMS.CURRENT_ACTUAL_REINSURANCE_SUBSIDY_AMOUNT AS NVARCHAR) AS CMS,
 CAST(PDE.CURRENT_ACTUAL_REINSURANCE_SUBSIDY_AMOUNT AS NVARCHAR) AS PDE,
CAST(CADRE.CURRENT_ACTUAL_REINSURANCE_SUBSIDY_AMOUNT AS NVARCHAR) AS CADRE,
	''09'' AS SEQ      
FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + 
					'  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID' + '
		UNION 
		SELECT 
		''(10) Current Prospective Reinsurance Subsidy Amount (From CMS MMR)'' AS TEXT,
		CAST(CLAIMS.CURRENT_PROSPECTIVE_REINSURANCE_SUBSIDY_AMOUNT AS NVARCHAR) AS CLAIMS,
		CAST(CMS.CURRENT_PROSPECTIVE_REINSURANCE_SUBSIDY_AMOUNT AS NVARCHAR) AS CMS,
		CAST(PDE.CURRENT_PROSPECTIVE_REINSURANCE_SUBSIDY_AMOUNT AS NVARCHAR) AS PDE,
CAST(CADRE.CURRENT_PROSPECTIVE_REINSURANCE_SUBSIDY_AMOUNT AS NVARCHAR) AS CADRE,
	''10'' AS SEQ    


FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + 
					'  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID' + '
		UNION
		SELECT 
		''(11) Current Reinsurance Subsidy Adjustment Amount (=[9] * 0.95 )'' AS TEXT, 
		CAST(CLAIMS.CURRENT_REINSURANCE_SUBSIDY_ADJUSTMENT_AMOUNT AS NVARCHAR) AS CLAIMS,
		CAST(CMS.CURRENT_REINSURANCE_SUBSIDY_ADJUSTMENT_AMOUNT AS NVARCHAR) AS CMS,
		CAST(PDE.CURRENT_REINSURANCE_SUBSIDY_ADJUSTMENT_AMOUNT AS NVARCHAR) AS PDE,
CAST(CADRE.CURRENT_REINSURANCE_SUBSIDY_ADJUSTMENT_AMOUNT AS NVARCHAR) AS CADRE,
	''11'' AS SEQ    
FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + 
					' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
				LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID
				) A
		ORDER BY SEQ'
			WHEN @pFieldName LIKE '%RISK'
				THEN '
	SELECT * FROM(
	SELECT 
	''(1) Total Covered Part D Plan Paid (CPP)'' AS TEXT,
	CAST(CLAIMS.TOTAL_COVERED_PARTD_PLAN_PAID AS NVARCHAR)  AS CLAIMS,                                                                            
	CAST(CMS.TOTAL_COVERED_PARTD_PLAN_PAID AS NVARCHAR)  AS CMS,
	CAST(PDE.TOTAL_COVERED_PARTD_PLAN_PAID AS NVARCHAR)  AS PDE,
	CAST(CADRE.TOTAL_COVERED_PARTD_PLAN_PAID AS NVARCHAR)  AS CADRE,
	''01'' AS SEQ  

	                                                                                    
		FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + 
					'  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID' + ' UNION

SELECT 
''(2) Induced Utilization Ratio (From bid)'' AS TEXT, 
CAST(CLAIMS.INDUCED_UTILIZATION_RATIO AS NVARCHAR)+''**'' AS CLAIMS,         
CAST(CMS.INDUCED_UTILIZATION_RATIO AS NVARCHAR)+''**''  AS CMS,
CAST(PDE.INDUCED_UTILIZATION_RATIO AS NVARCHAR)+''**''  AS PDE,
CAST(CADRE.INDUCED_UTILIZATION_RATIO AS NVARCHAR)+''**'' AS CADRE,
	''02'' AS SEQ    

		FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + 
					'  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID' + '
		UNION 
		SELECT 
		''(3) Adjusted Allowable Risk Corridor Cost Amount'' AS TEXT,
		CAST(CLAIMS.ADJUSTED_ALLOWABLE_RISK_CORRIDOR_COST_AMOUNT AS NVARCHAR) AS CLAIMS,
		CAST(CMS.ADJUSTED_ALLOWABLE_RISK_CORRIDOR_COST_AMOUNT AS NVARCHAR) AS CMS,
		CAST(PDE.ADJUSTED_ALLOWABLE_RISK_CORRIDOR_COST_AMOUNT AS NVARCHAR) AS PDE,
CAST(CADRE.ADJUSTED_ALLOWABLE_RISK_CORRIDOR_COST_AMOUNT AS NVARCHAR) AS CADRE,
	''03'' AS SEQ    


FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + 
					'  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID' + '
		UNION
		SELECT 
		''(4) Direct Subsidy Amount (From CMS MMR)'' AS TEXT, 
		CAST(CLAIMS.DIRECT_SUBSIDY_AMOUNT AS NVARCHAR) AS CLAIMS,
		CAST(CMS.DIRECT_SUBSIDY_AMOUNT AS NVARCHAR) AS CMS,
		CAST(PDE.DIRECT_SUBSIDY_AMOUNT AS NVARCHAR) AS PDE,
CAST(CADRE.DIRECT_SUBSIDY_AMOUNT AS NVARCHAR) AS CADRE,
	''04'' AS SEQ    
FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + 
					'  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID' + '
UNION
 SELECT 
 ''(5) Part D Basic Premium Amount (From CMS MMR)'' AS TEXT,
 CAST(CLAIMS.PART_D_BASIC_PREMIUM_AMOUNT AS NVARCHAR) AS CLAIMS, 
 CAST(CMS.PART_D_BASIC_PREMIUM_AMOUNT AS NVARCHAR) AS CMS,
 CAST(PDE.PART_D_BASIC_PREMIUM_AMOUNT AS NVARCHAR) AS PDE,
CAST(CADRE.PART_D_BASIC_PREMIUM_AMOUNT AS NVARCHAR) AS CADRE ,
	''05'' AS SEQ     
FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + 
					'  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID' + ' UNION

SELECT 
''(6) Administrative Cost Ratio (From bid)'' AS TEXT, 
CAST(CLAIMS.ADMINISTRATIVE_COST_RATIO AS NVARCHAR)+''**''  AS CLAIMS,         
CAST(CMS.ADMINISTRATIVE_COST_RATIO AS NVARCHAR) +''**'' AS CMS,
CAST(PDE.ADMINISTRATIVE_COST_RATIO AS NVARCHAR)+''**''  AS PDE,
CAST(CADRE.ADMINISTRATIVE_COST_RATIO AS NVARCHAR)+''**''  AS CADRE  ,
	''06'' AS SEQ    

		FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + 
					'  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID' + '
		UNION 
		SELECT 
		''(7) PACE Cost Sharing Add On Amount'' AS TEXT,
		CAST(CLAIMS.PACE_COST_SHARING_ADD_ON_AMOUNT AS NVARCHAR) AS CLAIMS,
		CAST(CMS.PACE_COST_SHARING_ADD_ON_AMOUNT AS NVARCHAR) AS CMS,
		CAST(PDE.PACE_COST_SHARING_ADD_ON_AMOUNT AS NVARCHAR) AS PDE,
CAST(CADRE.PACE_COST_SHARING_ADD_ON_AMOUNT AS NVARCHAR) AS CADRE,
	''07'' AS SEQ    


FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + 
					'  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID' + '
		UNION
		SELECT 
		''(8) Target Amount (=([4]+[5])*(1-[6])-[7] )'' AS TEXT, 
		CAST(CLAIMS.TARGET_AMOUNT AS NVARCHAR) AS CLAIMS,
		CAST(CMS.TARGET_AMOUNT AS NVARCHAR) AS CMS,
		CAST(PDE.TARGET_AMOUNT AS NVARCHAR) AS PDE,
CAST(CADRE.TARGET_AMOUNT AS NVARCHAR) AS CADRE,
	''08'' AS SEQ    
FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + 
					'  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID' + '
UNION
 SELECT 
 ''(9) First Upper Threshold Amount (=[8]*1.05 )'' AS TEXT,
 CAST(CLAIMS.FIRST_UPPER_THRESHOLD_AMOUNT AS NVARCHAR) AS CLAIMS, 
 CAST(CMS.FIRST_UPPER_THRESHOLD_AMOUNT AS NVARCHAR) AS CMS,
 CAST(PDE.FIRST_UPPER_THRESHOLD_AMOUNT AS NVARCHAR) AS PDE,
CAST(CADRE.FIRST_UPPER_THRESHOLD_AMOUNT AS NVARCHAR) AS CADRE,
	''09'' AS SEQ      
FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + 
					'  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID' + '
		UNION 
		SELECT 
		''(10) Second Upper Threshold Amount (=[8]*1.10 )'' AS TEXT,
		CAST(CLAIMS.SECOND_UPPER_THRESHOLD_AMOUNT AS NVARCHAR) AS CLAIMS,
		CAST(CMS.SECOND_UPPER_THRESHOLD_AMOUNT AS NVARCHAR) AS CMS,
		CAST(PDE.SECOND_UPPER_THRESHOLD_AMOUNT AS NVARCHAR) AS PDE,
CAST(CADRE.SECOND_UPPER_THRESHOLD_AMOUNT AS NVARCHAR) AS CADRE,
	''10'' AS SEQ    


FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + 
					'  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID' + '
		UNION
		SELECT 
		''(11) First Lower Threshold Amount (=[[8]*0.95 )'' AS TEXT, 
		CAST(CLAIMS.FIRST_LOWER_THRESHOLD_AMOUNT AS NVARCHAR) AS CLAIMS,
		CAST(CMS.FIRST_LOWER_THRESHOLD_AMOUNT AS NVARCHAR) AS CMS,
		CAST(PDE.FIRST_LOWER_THRESHOLD_AMOUNT AS NVARCHAR) AS PDE,
CAST(CADRE.FIRST_LOWER_THRESHOLD_AMOUNT AS NVARCHAR) AS CADRE,
	''11'' AS SEQ    
FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + 
					'  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID 
		' + '
		UNION
		SELECT 
		''(12) Second Lower Threshold Amount (=[8]*0.90 )'' AS TEXT, 
		CAST(CLAIMS.SECOND_LOWER_THRESHOLD_AMOUNT AS NVARCHAR) AS CLAIMS,
		CAST(CMS.SECOND_LOWER_THRESHOLD_AMOUNT AS NVARCHAR) AS CMS,
		CAST(PDE.SECOND_LOWER_THRESHOLD_AMOUNT AS NVARCHAR) AS PDE,
CAST(CADRE.SECOND_LOWER_THRESHOLD_AMOUNT AS NVARCHAR) AS CADRE,
	''12'' AS SEQ    
FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + 
					'  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID 
		' +
					--		'
					--		UNION
					--		SELECT 
					--		''(13) Cost Over First Upper Threshold'' AS TEXT, 
					--		CAST(CLAIMS.COST_OVER_FIRST_UPPER_THRESHOLD AS NVARCHAR)+''**''  AS CLAIMS,
					--		CAST(CMS.COST_OVER_FIRST_UPPER_THRESHOLD AS NVARCHAR) +''**'' AS CMS,
					--		CAST(PDE.COST_OVER_FIRST_UPPER_THRESHOLD AS NVARCHAR)+''**''  AS PDE,
					--CAST(CADRE.COST_OVER_FIRST_UPPER_THRESHOLD AS NVARCHAR) AS CADRE,
					--	''13'' AS SEQ    
					--FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY '+ @WhereCondition+' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
					--		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY '+ @WhereCondition+'  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
					--		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY '+ @WhereCondition+'  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
					--		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY '+ @WhereCondition+'  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID '
					--		+
					'
		UNION
		SELECT 
		''(13) Current Risk Sharing Amount (Please see CMS Mannual )'' AS TEXT, 
		CAST(CLAIMS.CURRENT_RISK_SHARING_AMOUNT AS NVARCHAR) AS CLAIMS,
		CAST(CMS.CURRENT_RISK_SHARING_AMOUNT AS NVARCHAR) AS CMS,
		CAST(PDE.CURRENT_RISK_SHARING_AMOUNT AS NVARCHAR) AS PDE,
CAST(CADRE.CURRENT_RISK_SHARING_AMOUNT AS NVARCHAR) AS CADRE,
	''14'' AS SEQ    
FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID ' + 
					'
		UNION
		SELECT 
		''(14) Risk Sharing Portion From Cost Beyond Second Limit (Information only)'' AS TEXT, 
		CAST(CLAIMS.RISK_SHARING_PORTION_FROM_COST_BEYOND_SECOND_LIMIT AS NVARCHAR) AS CLAIMS,
		CAST(CMS.RISK_SHARING_PORTION_FROM_COST_BEYOND_SECOND_LIMIT AS NVARCHAR) AS CMS,
		CAST(PDE.RISK_SHARING_PORTION_FROM_COST_BEYOND_SECOND_LIMIT AS NVARCHAR) AS PDE,
CAST(CADRE.RISK_SHARING_PORTION_FROM_COST_BEYOND_SECOND_LIMIT AS NVARCHAR) AS CADRE,
	''15'' AS SEQ    
FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + 
					'  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID ' + '
		UNION
		SELECT 
		''(15) Risk Sharing Portion From Cost Between First And Second Limit (Information only)'' AS TEXT, 
		CAST(CLAIMS.RISK_SHARING_PORTION_FROM_COST_BETWEEN_FIRST_AND_SECOND_LIMIT AS NVARCHAR) AS CLAIMS,
		CAST(CMS.RISK_SHARING_PORTION_FROM_COST_BETWEEN_FIRST_AND_SECOND_LIMIT AS NVARCHAR) AS CMS,
		CAST(PDE.RISK_SHARING_PORTION_FROM_COST_BETWEEN_FIRST_AND_SECOND_LIMIT AS NVARCHAR) AS PDE,
CAST(CADRE.RISK_SHARING_PORTION_FROM_COST_BETWEEN_FIRST_AND_SECOND_LIMIT AS NVARCHAR) AS CADRE,
	''16'' AS SEQ    
FROM (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + ' AND DATA_SOURCE = ''CLAIMS'') CLAIMS
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''PDE'') PDE ON CLAIMS.PBP = PDE.PBP AND CLAIMS.PLAN_ID = PDE.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + 
					'  AND DATA_SOURCE = ''CMSPRS'') CMS ON CLAIMS.PBP = CMS.PBP AND CLAIMS.PLAN_ID = CMS.PLAN_ID
		LEFT JOIN (select * FROM PDE_PRS_ANNUALLY_SUMMARY ' + @WhereCondition + '  AND DATA_SOURCE = ''CADRE360'') CADRE ON CLAIMS.PBP = CADRE.PBP AND CLAIMS.PLAN_ID = CADRE.PLAN_ID 
) A		
ORDER BY SEQ' + @OffsetText
			END

	PRINT @pSQL

	EXEC sp_sqlexec @pSQL
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

PRINT N'Creating [dbo].[PDE_REC_POPUP_INSERT]'
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PDE_REC_POPUP_INSERT] @pClamId VARCHAR(50) = ''
	,@pUpdatePerson VARCHAR(100) = ''
	,@pComments NVARCHAR(max) = ''
	,@pUpdateTime DATETIME = ''
	,@ErrorMessage VARCHAR(255) = '' OUTPUT
AS
BEGIN
	SET NOCOUNT ON

	--internal SP parameter
	DECLARE @MemberID NVARCHAR(50) = ''
		,@UpdateTime DATETIME = GETDATE()

	PRINT @UpdateTime

	IF @pClamId IS NULL
		OR @pClamId = ''
		SET @pClamId = N'1918630'
	SET @MemberID = (
			SELECT RX_MEME_ID
			FROM RX_CLAIMS
			WHERE CLAM_ID = @pClamId
			)

	IF NOT (
			@pComments IS NULL
			OR @pComments = ''
			)
	BEGIN
		PRINT 'entering comment loop'
		PRINT @pUpdatePerson

		SELECT @UpdateTime

		SELECT @pComments

		SELECT @pClamId

		INSERT INTO dbo.PDE_REC_NOTES_REJ (
			CLAM_ID
			,UPDATE_STATUS_PERSON
			,UPDATE_STATUS_DATE
			,NOTES
			,MEMBER_ID
			)
		VALUES (
			@pClamId
			,@pUpdatePerson
			,@UpdateTime
			,@pComments
			,@MemberID
			)
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

PRINT N'Creating [dbo].[PDE_REC_MEMBER_DETAILS_TITLE]'
GO

CREATE PROCEDURE [dbo].[PDE_REC_MEMBER_DETAILS_TITLE] (
	@pKey VARCHAR(50) = ''
	,@pAccuYear VARCHAR(4) = ''
	,@pPdeStatus VARCHAR(10) = ''
	,@pProductID NVARCHAR(10) = NULL
	,@pGroupField NVARCHAR(100) = ''
	,@pGroupValue NVARCHAR(max) = ''
	,@pFieldName VARCHAR(8000) = ''
	,@pMonth NVARCHAR(2) = ''
	,@pFirstErrorOnly VARCHAR(1) = ''
	,@pSQL NVARCHAR(max) = '' OUTPUT
	)
AS
BEGIN
	DECLARE @pCode NVARCHAR(max) = ''
		,@type VARCHAR(55) = ''
		,@switch VARCHAR(55) = ''
		,@string NVARCHAR(500) = ''
		,@pos INT
		,@piece NVARCHAR(500)
		,@counter INT
		,@pErrorCodes VARCHAR(50)
		,@pFromStatement NVARCHAR(max) = ''
		,@MemberID NVARCHAR(50)

	SET @MemberID = (
			SELECT RX_MEME_ID
			FROM RX_CLAIMS
			WHERE CLAM_ID = @pKey
			)

	--SET DEFAULT PARAMETERS
	IF @pAccuYear IS NULL
		OR @pAccuYear = ''
		SET @pAccuYear = YEAR(GETDATE())

	IF @MemberID IS NULL
		OR @MemberID = ''
		SET @MemberID = '19961108510900'
	SET @pFromStatement = CASE 
			WHEN upper(@pFirstErrorOnly) = 'Y'
				THEN 'FROM dbo.RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA A
		JOIN RX_CLAIMS B ON A.CLAIM_ID = B.CLAM_ID AND A.PDE_SEQ = B.PDE_SEQ
		LEFT join RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA_GAP C ON A.CLAIM_ID = C.CLAM_ID AND A.PDE_SEQ = C.PDE_SEQ
		JOIN MB_ENROLLEE_INFO D ON B.RX_MEME_ID = D.MEMBER_ID
		LEFT JOIN RX_NDC_DRUGS E ON B.DRUG_NDC_CODE = E.DRUG_NDC_CODE
		JOIN dbo.RX_CMS_PDED_DETAIL_ERROR_CODE PDEDD ON A.CLAIM_ID=PDEDD.CLAIM_ID AND A.ERROR_SUBMISSION_NUM = PDEDD.ERROR_SUBMISSION_NUM AND SUBSTRING(A.ERROR_CODE,1,3) = PDEDD.ERROR_CODE
		JOIN dbo.PDE_REJECT_CODE PDER on PDEDD.ERROR_CODE = PDER.ERROR_CODE'
			ELSE 'FROM dbo.RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA A
		INNER JOIN RX_CLAIMS B ON A.CLAIM_ID = B.CLAM_ID AND A.PDE_SEQ = B.PDE_SEQ 
		LEFT join RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA_GAP C ON A.CLAIM_ID = C.CLAM_ID AND A.PDE_SEQ = C.PDE_SEQ
		JOIN MB_ENROLLEE_INFO D ON B.RX_MEME_ID = D.MEMBER_ID
		LEFT JOIN RX_NDC_DRUGS E ON B.DRUG_NDC_CODE = E.DRUG_NDC_CODE
		INNER JOIN dbo.RX_CMS_PDED_DETAIL_ERROR_CODE PDEDD ON A.CLAIM_ID=PDEDD.CLAIM_ID
		INNER JOIN dbo.PDE_REJECT_CODE PDER ON PDEDD.ERROR_CODE = PDER.ERROR_CODE AND A.ERROR_SUBMISSION_NUM = PDEDD.ERROR_SUBMISSION_NUM'
			END
	--Set columns for select statement
	SET @pSQL = 'SELECT 
		    B.CLAM_ID,	
			CLAM_CHECK_REFERENCE_NUMBER AS [PBM_ID], 
			E.DRUG_NAME
			,CLAM_ORIGINAL_ENTRY_DATE
			,CLAM_FILL_DATE
			,B.TGCDCA
		  '

	--If set to All, will collect all information for member
	IF @pFieldName <> 'ALL'
	BEGIN
		--parse _ delimited FieldName parameter.  Use the variable @type in both Rej and (ACC or OUT or INF or ALL)
		SET @string = @pFieldName
		SET @counter = 1

		IF right(RTRIM(@string), 1) <> '_'
			SELECT @string = @string + '_'

		SELECT @pos = patindex('%[_]%', @string)

		WHILE @pos <> 0
		BEGIN
			SELECT @piece = left(@string, (@pos - 1))

			IF @counter = 1
				SET @type = cast(@piece AS NVARCHAR(512))
			SET @counter = @counter + 1

			SELECT @string = stuff(@string, 1, @pos, '')

			SELECT @pos = patindex('%[_]%', @string)
		END
	END

	IF @pPdeStatus = 'REJ'
	BEGIN
		IF (
				@pGroupField IS NULL
				OR @pGroupField = ''
				)
			SET @pGroupField = 'ERROR_AGING'

		--Group value is the type of chart on PDE rej page
		PRINT @pGroupValue

		IF (
				@pGroupValue IS NULL
				OR @pGroupValue = ''
				)
		BEGIN
			SET @pGroupValue = CASE 
					WHEN @pGroupField = 'ERROR_AGING'
						THEN '%'
					WHEN @pGroupField = 'EDIT_CATEGORY'
						THEN '%'
					WHEN @pGroupField = 'SERVICE_YEAR'
						THEN '%'
					WHEN @pGroupField = 'RESUBMIT'
						THEN '%'
					END
		END

		IF (
				@pFieldName IS NULL
				OR @pFieldName = ''
				)
			SET @pFieldName = 'ERRORS_AMOUNT'

		IF (
				@pProductID IS NULL
				OR @pProductID = ''
				)
			SET @pProductID = '%%'

		--if you don't have a conditional for serivce year, you will end up with a duplicate YEAR(PAID_DT) = X
		IF @pGroupField <> 'SERVICE_YEAR'
			SET @pCode = ' AND YEAR(A.PAID_DT) = ''' + @pAccuYear + ''' '

		--		IF NOT (@pMonth is null or @pMonth = '') and @pGroupField = 'TREND' 
		-- 7/27/2014 Add Month option to the query
		IF NOT (
				@pMonth IS NULL
				OR @pMonth = ''
				)
			SET @pCode = @pCode + ' AND MONTH(A.PAID_DT) = ''' + @pMonth + ''''
		SET @pCode = @pCode + 'AND PDPD_ID LIKE ''' + @pProductID + ''' '

		--ALL = CAT + COST + ERRORS + NDC + LICS + GAP + ENROLL
		IF @pFieldName <> 'ALL'
		BEGIN
			--set @pErrorCodes to proper nomenclature
			SET @pErrorCodes = CASE 
					WHEN @type = 'CAT'
						THEN 'Catastrophic'
					WHEN @type = 'COST'
						THEN 'Claims Cost'
					WHEN @type = 'ERRORS'
						THEN 'Claims Errors'
					WHEN @type = 'NDC'
						THEN 'Drug NDC Code'
					WHEN @type = 'LICS'
						THEN 'Claims LICS'
					WHEN @type = 'GAP'
						THEN 'Gap Discount'
					WHEN @type = 'ENROLL'
						THEN 'Member Enrollment'
					END
			--add this to pCode
			SET @pCode = @pCode + ' AND PDER.EDIT_CATEGORY = ''' + @pErrorCodes + ''''

			--Set value for condition
			IF @pGroupValue = '%'
				SET @switch = CASE 
						WHEN @pGroupField = 'ERROR_AGING'
							THEN ' AGING.CODE_TYPE_DESC LIKE '''
						WHEN @pGroupField = 'EDIT_CATEGORY'
							THEN ' EDITES LIKE '''
						WHEN @pGroupField = 'RESUBMIT'
							THEN ' A.ERROR_SUBMISSION_NUM LIKE '''
						WHEN @pGroupField = 'SERVICE_YEAR'
							THEN ' YEAR(A.FILL_DT) LIKE '''
						END
			ELSE
				SET @switch = CASE 
						WHEN @pGroupField = 'ERROR_AGING'
							THEN ' AGING.CODE_TYPE_DESC = '''
						WHEN @pGroupField = 'EDIT_CATEGORY'
							THEN ' EDITES LIKE '''
						WHEN @pGroupField = 'RESUBMIT'
							THEN ' A.ERROR_SUBMISSION_NUM ='''
						WHEN @pGroupField = 'SERVICE_YEAR'
							THEN ' YEAR(A.FILL_DT) = '''
						END

			PRINT @pGroupField
			PRINT @pCode

			--parse _ delimited GroupValue parameter, not required for Trend graph
			IF @pGroupField <> 'TREND'
			BEGIN
				SET @counter = 1
				SET @pCode = @pCode + ' AND ('
				SET @string = @pGroupValue

				IF right(RTRIM(@string), 1) <> '|'
					SELECT @string = @string + '|'

				SELECT @pos = patindex('%[|]%', @string)

				WHILE @pos <> 0
				BEGIN
					SELECT @piece = left(@string, (@pos - 1))

					--build pCode String
					IF @counter <> 1
						SET @pCode = @pCode + 'OR '

					--only select numbers from resubmit, I.E. Change "2 resubmission" to "2"
					IF @pGroupField = 'RESUBMIT'
						SET @piece = SUBSTRING(@piece, 1, CHARINDEX(' ', @piece) - 1)

					IF @pGroupField = 'EDIT_CATEGORY'
						SET @pCode = @pCode + @switch + @piece + '%'' '
					ELSE
						SET @pCode = @pCode + @switch + @piece + ''' '

					SET @counter = @counter + 1

					SELECT @string = stuff(@string, 1, @pos, '')

					SELECT @pos = patindex('%[|]%', @string)
				END

				SET @pCode = @pCode + ' )'
			END
		END

		PRINT @pCode

		--Add extra columns for Rejected Member Pop up
		SET @pSQL = @pSQL + ', PDER.ERROR_CODE, EDITES
				' + @pFromStatement + '
				JOIN SUP_SUPPORT_CODE AGING ON CODE_TYPE=''DAY_RANGE'' AND DATEDIFF(DAY,BATCH_DATE,GETDATE()) BETWEEN CAST(CODE AS INT) AND CAST(CODE_DESC AS INT)
				LEFT JOIN MB_MEMBER_ELIGIBILITY ELIG ON B.MEMBER_CK = ELIG.MEMBER_CK AND B.CLAM_FILL_DATE BETWEEN EFFECTIVE_DATE AND TERMINATION_DATE
				WHERE DRUG_COVERAGE_STATUS_CODE IN (''C'',''E'',''O'') and A.STATUS=''REJ'' AND B.RX_MEME_ID = ''' + @MemberID + '''' + @pCode + ' order by CLAM_ORIGINAL_ENTRY_DATE,CLAM_FILL_DATE,B.TGCDCA,CLAM_ID'

		--create temporary table to store results of pop up (ERROR CODES AND EDITES)
		---used to seperate formatting of text (<br><br\>) and select query
		CREATE TABLE #temp (
			CLAM_ID NVARCHAR(25)
			,PBM_ID NVARCHAR(100)
			,DRUG_NAME NVARCHAR(100)
			,CLAM_ORIGINAL_ENTRY_DATE DATETIME
			,CLAM_FILL_DATE DATETIME
			,TGDCA MONEY
			,ERROR_CODE NVARCHAR(100)
			,EDITES NVARCHAR(max)
			)

		--insert data into the temporary table
		PRINT @pSQL

		INSERT INTO #temp
		EXEC sp_executesql @pSQL
			,N'@pPDE_STAT nvarchar(75)'
			,@pPDE_STAT = @pPdeStatus

		--reformat the output in below format. This is for the rejected page pop up
		--=##==#Claim ID: [claim ID #]#==#[drug name]#==#[error code]#==#[error description]#=
		--for COLOR_PICKER, use [error code] for now
		SELECT DISTINCT '=# Claim ID: ' + PBM_ID + '#==#' + DRUG_NAME + '#==#' +
			--creates a - delimited list for each claim
			STUFF((
					SELECT '-' + A.[ERROR_CODE]
					FROM #temp A
					WHERE A.[PBM_ID] = B.[PBM_ID]
					FOR XML PATH('')
						,type
					).value('.', 'nvarchar(max)'), 1, 1, '') + '#==#' +
			--creates a ',' delimited list for error descriptions
			--stuff will create an extra ',' at the begining of the string, substring removes this
			STUFF((
					SELECT '-' + A.[EDITES]
					FROM #temp A
					WHERE A.[PBM_ID] = B.[PBM_ID]
					FOR XML PATH('')
						,type
					).value('.', 'nvarchar(max)'), 1, 1, '') + '#=' AS TITLE
			,NULL AS COLOR_PICKER
		FROM #temp B
	END
	ELSE
	BEGIN
		--build condition for status that should be returned, ALL = INF + ACC + OUT + REJ
		SET @pCode = CASE 
				WHEN (@pPdeStatus = 'ALL')
					THEN ' '
				WHEN @pPdeStatus = 'ACC'
					THEN '( @pPDE_STAT = ISNULL(A.STATUS,'''') OR A.STATUS = ''INF'' OR A.STATUS = ''CLN'') '
				WHEN @pPdeStatus = 'INF'
					THEN '( @pPDE_STAT = ISNULL(A.STATUS,'''') OR A.STATUS = ''ACC'' OR A.STATUS = ''CLN'') '
				WHEN @pPdeStatus = NULL
					OR @pPdeStatus = ''
					THEN ' ISNULL(@pPDE_STAT, '''') = ISNULL(A.STATUS,'''') '
				END

		IF NOT (
				@pMonth IS NULL
				OR @pMonth = ''
				)
			SET @pCode = @pCode + ' AND MONTH(A.PAID_DT) = ''' + @pMonth + ''' '

		IF @pFieldName <> 'ALL'
		BEGIN
			--set @pCode to proper nomenclature
			SET @pCode = CASE 
					WHEN @type = 'OTC'
						THEN @pCode + ' AND DRUG_COVERAGE_STATUS_CODE = ''O'''
					WHEN @type = 'ENHANCED'
						THEN @pCode + ' AND DRUG_COVERAGE_STATUS_CODE = ''E'''
					WHEN @type = 'COVERED'
						THEN @pCode + ' AND DRUG_COVERAGE_STATUS_CODE = ''C'''
					WHEN (
							@type <> 'OTC'
							AND @type <> 'ENHANCED'
							AND @type <> 'COVERED'
							AND @type <> ''
							)
						THEN @pCode + ' AND A.' + @type + ' <> 0 '
					WHEN @type = ''
						THEN @pCode
					END
		END

		SET @pSQL = 'SELECT ''=# Claim ID: '' +PBM_ID+''#==#''+	DRUG_NAME+''#='' AS TITLE, NULL AS COLOR_PICKER FROM ( ' + @pSQL + '
					FROM dbo.RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA A
				JOIN RX_CLAIMS B ON A.CLAIM_ID = B.CLAM_ID AND A.PDE_SEQ = B.PDE_SEQ
				LEFT join RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA_GAP C ON A.CLAIM_ID = C.CLAM_ID AND A.PDE_SEQ = C.PDE_SEQ
				JOIN MB_ENROLLEE_INFO D ON B.RX_MEME_ID = D.MEMBER_ID
				FULL JOIN RX_NDC_DRUGS E ON B.DRUG_NDC_CODE = E.DRUG_NDC_CODE
					WHERE ' + @pCode + ' AND B.RX_MEME_ID = ''' + @MemberID + ''' and YEAR(PAID_DT) = ''' + @pAccuYear + ''' AND DRUG_COVERAGE_STATUS_CODE IN (''C'',''E'',''O'')
					) temp 
					order by CLAM_ORIGINAL_ENTRY_DATE,CLAM_FILL_DATE,TGCDCA,CLAM_ID'

		PRINT @pSQL

		EXEC sp_executesql @pSQL
			,N'@pPDE_STAT nvarchar(75)'
			,@pPDE_STAT = @pPdeStatus
	END

	DROP TABLE #temp
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

PRINT N'Creating [dbo].[PDE_REC_CLAIM_DETAILS_REJ_TITLE]'
GO

CREATE PROCEDURE [dbo].[PDE_REC_CLAIM_DETAILS_REJ_TITLE] (
	@pKey VARCHAR(50) = ''
	,@pPdeStatus VARCHAR(10) = ''
	,@pProductID NVARCHAR(10) = NULL
	,@pMonth NVARCHAR(2) = ''
	,@pFirstErrorOnly VARCHAR(1) = ''
	,@pSQL NVARCHAR(max) = '' OUTPUT
	)
AS
BEGIN
	DECLARE @pWhereCondition NVARCHAR(max) = ''
		,@pFromStatement NVARCHAR(max) = ''
		,@JoinParameter NVARCHAR(1000) = ''
		,@PbmID NVARCHAR(50) = ''
		,@ClaimID NVARCHAR(50) = ''

	SET @ClaimID = @pKey

	--SET DEFAULT PARAMETERS
	IF @ClaimID IS NULL
		OR @ClaimID = ''
		SET @ClaimID = '1826937'

	SELECT @PbmID = (
			SELECT CLAM_CHECK_REFERENCE_NUMBER
			FROM RX_CLAIMS
			WHERE CLAM_ID = @ClaimID
			)

	SET @pWhereCondition = 'CLAM_CHECK_REFERENCE_NUMBER= ''' + @PbmID + ''' AND DRUG_COVERAGE_STATUS_CODE IN (''C'',''E'',''O'')'
	--PRINT @PbmID
	SET @pFromStatement = CASE 
			WHEN upper(@pFirstErrorOnly) = 'Y'
				THEN 'FROM dbo.RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA A
		JOIN RX_CLAIMS B ON A.CLAIM_ID = B.CLAM_ID --AND A.PDE_SEQ = B.PDE_SEQ
		LEFT join RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA_GAP C ON A.CLAIM_ID = C.CLAM_ID AND A.PDE_SEQ = C.PDE_SEQ
		JOIN MB_ENROLLEE_INFO D ON B.RX_MEME_ID = D.MEMBER_ID
		LEFT JOIN RX_NDC_DRUGS E ON B.DRUG_NDC_CODE = E.DRUG_NDC_CODE
		JOIN dbo.RX_CMS_PDED_DETAIL_ERROR_CODE PDEDD ON A.CLAIM_ID=PDEDD.CLAIM_ID AND A.ERROR_SUBMISSION_NUM = PDEDD.ERROR_SUBMISSION_NUM AND SUBSTRING(A.ERROR_CODE,1,3) = PDEDD.ERROR_CODE
		JOIN dbo.PDE_REJECT_CODE PDER on PDEDD.ERROR_CODE = PDER.ERROR_CODE'
			ELSE 'FROM dbo.RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA A
		INNER JOIN RX_CLAIMS B ON A.CLAIM_ID = B.CLAM_ID --AND A.PDE_SEQ = B.PDE_SEQ 
		LEFT join RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA_GAP C ON A.CLAIM_ID = C.CLAM_ID AND A.PDE_SEQ = C.PDE_SEQ
		JOIN MB_ENROLLEE_INFO D ON B.RX_MEME_ID = D.MEMBER_ID
		LEFT JOIN RX_NDC_DRUGS E ON B.DRUG_NDC_CODE = E.DRUG_NDC_CODE
		INNER JOIN dbo.RX_CMS_PDED_DETAIL_ERROR_CODE PDEDD ON A.CLAIM_ID=PDEDD.CLAIM_ID
		INNER JOIN dbo.PDE_REJECT_CODE PDER ON PDEDD.ERROR_CODE = PDER.ERROR_CODE AND A.ERROR_SUBMISSION_NUM = PDEDD.ERROR_SUBMISSION_NUM'
			END
	--Set columns for select statement
	SET @pSQL = '(SELECT B.RX_MEME_ID AS MEMBER_ID,
			MEMBER_NAME,
			B.CLAM_ID,
			A.STATUS,
			CLAM_CHECK_REFERENCE_NUMBER AS [PBM_ID], 
			E.DRUG_NDC_CODE as DRUG_NDC,
			CLAM_ORIGINAL_ENTRY_DATE AS PAID_DT,
			E.DRUG_NAME,
			FILL_DT
'
	SET @pSQL = @pSQL + ',PDER.ERROR_CODE, EDITES
		' + @pFromStatement + '
		JOIN SUP_SUPPORT_CODE AGING ON CODE_TYPE=''DAY_RANGE'' AND DATEDIFF(DAY,BATCH_DATE,GETDATE()) BETWEEN CAST(CODE AS INT) AND CAST(CODE_DESC AS INT)
		LEFT JOIN MB_MEMBER_ELIGIBILITY ELIG ON B.MEMBER_CK = ELIG.MEMBER_CK AND B.CLAM_FILL_DATE BETWEEN EFFECTIVE_DATE AND TERMINATION_DATE
		WHERE ' + @pWhereCondition + ' )'
	-- CONCTENATE ERROR CODES
	-- Formatting output to retrieve data in this format =##==#Claim ID: [claim ID #]#==#[drug name]#==#[error code]#==#[error description]#=
	SET @pSQL = 'SELECT ''=# Claim ID: '' +PBM_ID+''#==#''+	DRUG_NAME+''#==#''+ERROR_CODE+ ''#==#''+EDITES+''#='' AS TITLE, NULL AS COLOR_PICKER FROM ( ' + 'SELECT  DISTINCT 
	   PBM_ID , 		
	   PAID_DT ,		  
		DRUG_NAME ,			
	--creates a - delimited list for each claim
	STUFF((SELECT ''-'' + A.[ERROR_CODE] FROM ' + @pSQL + ' A
		Where A.[CLAM_ID]=B.[CLAM_ID] FOR XML PATH('''')),1,1,'''') As [ERROR_CODE],
	--creates a '','' delimited list for error descriptions
	--stuff will create an extra '','' at the begining of the string, substring removes this
	STUFF((SELECT '', '' + A.[EDITES] FROM ' + @pSQL + '  A
		Where A.[CLAM_ID]=B.[CLAM_ID] FOR XML PATH('''')),1,1,'''') As [EDITES]
	FROM ' + @pSQL + '  B 
	-- Moving the PAID_DT out becuase it is throwing an error
	--order by PAID_DT
	) temp 
					order by PAID_DT'

	PRINT @pSQL

	EXEC sp_executesql @pSQL
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

PRINT N'Creating [dbo].[PDE_REC_CLAIM_DETAILS_OUT_TITLE]'
GO

CREATE PROCEDURE [dbo].[PDE_REC_CLAIM_DETAILS_OUT_TITLE] (
	@pKey VARCHAR(50) = ''
	,@pPdeStatus VARCHAR(10) = ''
	,@pProductID NVARCHAR(10) = NULL
	,@pMonth NVARCHAR(2) = ''
	,@pFirstErrorOnly VARCHAR(1) = ''
	,@pSQL NVARCHAR(max) = '' OUTPUT
	)
AS
BEGIN
	DECLARE @pWhereCondition NVARCHAR(max) = ''
		,@pFromStatement NVARCHAR(max) = ''
		,@JoinParameter NVARCHAR(1000) = ''
		,@PbmID NVARCHAR(50) = ''
		,@ClaimID NVARCHAR(50) = ''

	SET @ClaimID = @pKey

	--SET DEFAULT PARAMETERS
	IF @ClaimID IS NULL
		OR @ClaimID = ''
		SET @ClaimID = '1826937'

	SELECT @PbmID = (
			SELECT CLAM_CHECK_REFERENCE_NUMBER
			FROM RX_CLAIMS
			WHERE CLAM_ID = @ClaimID
			)

	SET @pWhereCondition = 'CLAM_CHECK_REFERENCE_NUMBER = ''' + @PbmID + ''' AND DRUG_COVERAGE_STATUS_CODE IN (''C'',''E'',''O'')'
	--Set columns for select statement
	SET @pSQL = 'SELECT		
		 ''=# Claim ID: '' +CLAM_CHECK_REFERENCE_NUMBER +''#==#''+E.DRUG_NAME+''#='' AS TITLE
		 , NULL AS COLOR_PICKER
			--CLAM_CHECK_REFERENCE_NUMBER AS [PBM_ID], 		  
		--	E.DRUG_NAME'
	SET @pSQL = @pSQL + '
				FROM dbo.RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA A
			JOIN RX_CLAIMS B ON A.CLAIM_ID = B.CLAM_ID --AND A.PDE_SEQ = B.PDE_SEQ
			LEFT JOIN RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA_GAP C ON A.CLAIM_ID = C.CLAM_ID AND A.PDE_SEQ = C.PDE_SEQ
			JOIN MB_ENROLLEE_INFO D ON B.RX_MEME_ID = D.MEMBER_ID
			LEFT JOIN RX_NDC_DRUGS E ON B.DRUG_NDC_CODE = E.DRUG_NDC_CODE
				WHERE ' + @pWhereCondition + '
				order by CLAM_ORIGINAL_ENTRY_DATE'

	PRINT @pSQL

	EXEC sp_executesql @pSQL
		,N'@pDyanmicStatusVariable nvarchar(75)'
		,@pDyanmicStatusVariable = @pPdeStatus
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

PRINT N'Altering [dbo].[PHAR_FORM_TRACKER_ADD_DRUG_NDC]'
GO

ALTER PROCEDURE [dbo].[PHAR_FORM_TRACKER_ADD_DRUG_NDC] @pNDC VARCHAR(15) = ''
	,@pFormularyName NVARCHAR(50) = ''
	,@pFormularyYear NVARCHAR(4) = ''
	,@pGPILength INT = ''
	,@pCategoryName NVARCHAR(510) = ''
	,--Parameter not currently used, but required to make page refresh correctly
	@pClassName NVARCHAR(510) = ''
	,--Parameter not currently used, but required to make page refresh correctly
	@pTime NVARCHAR(100) = '' --Parameter not currently used, but required to make page refresh correctly
AS
BEGIN
	DECLARE @WhereCondition VARCHAR(2500) = ''
		,@GPICount NVARCHAR(10) = ''
		,@GPI NVARCHAR(14) = ''
		,@SQL NVARCHAR(MAX) = ''
		,@NDCBlankFlag NVARCHAR(1) = 'N'

	--set default values
	IF @pGPILength IS NULL
		OR @pGPILength = ''
		SET @pGPILength = 14

	IF @pFormularyYear IS NULL
		OR @pFormularyYear = ''
	BEGIN
		SELECT @pFormularyYear = (
				SELECT TOP 1 FRF_YEAR
				FROM PLAN_HPMS_FORMULARY_SUBMISSIONS
				WHERE FORMULARY_ID IS NOT NULL
					AND FRF_YEAR IS NOT NULL
				ORDER BY FRF_YEAR DESC
					,FORMULARY_ID
				)
	END

	--Set default formulary name
	IF (
			@pFormularyName = ''
			OR @pFormularyName IS NULL
			)
	BEGIN
		SELECT @pFormularyName = (
				SELECT TOP 1 FORMULARY_ID
				FROM PLAN_HPMS_FORMULARY_SUBMISSIONS A
				LEFT JOIN SUP_SUPPORT_CODE B ON A.FORMULARY_ID = B.CODE
				WHERE FORMULARY_ID IS NOT NULL
					AND FRF_YEAR = @pFormularyYear
					AND CODE_TYPE = 'DRUGFORMULARY'
				ORDER BY CODE_SUMMARY
				)
	END

	--set this flag for page load to send back a Yes value to allow DIV to be loaded
	IF @pNDC IS NULL
		OR @pNDC = ''
		SET @NDCBlankFlag = 'Y'

	IF @pNDC IS NULL
		OR @pNDC = ''
		SET @pNDC = '00378801593'

	--Get GPI for specified NDC
	SELECT @GPI = GNPR_ID
	FROM dbo.RX_NDC_DRUGS
	WHERE DRUG_NDC_CODE = @pNDC

	--truncate GPI to appropriate length
	SET @GPI = LEFT(@GPI, @pGPILength)

	--Get count of drugs with matching GPI
	SELECT @GPICount = COUNT(*)
	FROM dbo.RX_NDC_DRUGS
	WHERE GNPR_ID LIKE @GPI + '%'

	PRINT @GPICount

	--build where condition
	SET @WhereCondition = ' DRUGS.DRUG_NDC_CODE = ''' + @pNDC + ''' '
	--build select statement
	SET @SQL = 
		'SELECT TOP 1 
		CASE WHEN FRF.FORMULARY_ID IS NULL OR FRF_ACTION LIKE''DEL%'' THEN ''NO'' ELSE ''YES'' END AS COVERED 
	   	,FRF.THERAPEUTIC_CLASS_NAME
		,FRF.THERAPEUTIC_CATEGORY_NAME
		,DRUGS.GNPR_ID AS GPI
	    ,DRUG_NDC_CODE AS RELATED_NDC
	    ,DRUG_NAME
	    ,DRUGS.DRUG_FORM AS MEDI_FORM
	    ,DRUGS.DRUG_ROUTE AS MEDI_ROUTE
	    --,DRUGS.DRUG_FORM
	    ,CASE WHEN UPPER(FRF_ACTION) LIKE ''ADD%'' THEN ''Addition'' 
			  WHEN UPPER(FRF_ACTION) LIKE ''DEL%'' THEN ''Deletion''
			  WHEN UPPER(FRF_ACTION) LIKE ''UP%'' THEN ''Update''
		    END AS FRF_ACTION
        ,DATENAME(month,FRF.EFFECTIVE_DATE) + '' '' + CAST(YEAR(FRF.EFFECTIVE_DATE) AS CHAR(4)) AS EFFECTIVE_DATE
	    ,ISNULL(DRUG_ROUTE_LABEL,'''') AS DRUG_ROUTE_LABEL
	    ,CASE WHEN UPPER(DRUGS.DRUG_GENERIC_FLAG) = ''Y'' THEN ''G'' ELSE ''B'' END   as BRAND_FLAG
	    ,ISNULL(FRF.TIER_LEVEL,'''')  AS TIER_LEVEL
	    --,CASE WHEN FRF.QUANTITY_LIMIT_YN = 0 THEN ''N'' WHEN FRF.QUANTITY_LIMIT_YN <> ''0'' AND FRF.QUANTITY_LIMIT_YN IS NOT NULL THEN ''Y'' END AS QUANTITY_LIMIT_YN
	    ,DRUGS.DRUG_OTC_FLAG AS OTC_FLAG 
	    --,CASE WHEN FRF.STEP_THERAPY_TYPE = ''0''  OR FRF.STEP_THERAPY_TYPE IS NULL THEN ''N'' WHEN FRF.STEP_THERAPY_TYPE <> ''0'' AND FRF.STEP_THERAPY_TYPE IS NOT NULL THEN''Y'' ELSE ISNULL(CAST(FRF.STEP_THERAPY_TYPE AS NVARCHAR),'''') END AS STEP_THERAPY_YN
		,FRF.STEP_THERAPY_TYPE
		,ISNULL(CAST(FRF.STEP_THERAPY_STEP_VALUE AS NVARCHAR),'''') AS STEP_THERAPY_STEP_VALUE
		,FRF.STEP_THERAPY_GROUP_DESC
		--,FRF.STEP_THERAPY_TOTAL_GROUPS
		,CASE WHEN FRF.QUANTITY_LIMIT_AMOUNT IS NULL  THEN 0 ELSE FRF.QUANTITY_LIMIT_AMOUNT END AS QL
		,CASE WHEN FRF.QUANTITY_LIMIT_DAYS IS NULL THEN 0 ELSE FRF.QUANTITY_LIMIT_DAYS END AS QUANTITY_LIMIT_DAYS
		,FRF.PRIOR_AUTHORIZATION_GROUP_DESC
		,''N'' AS PART_D
	    ,ISNULL(FRF.PRIOR_AUTHORIZATION_TYPE,'''') AS  PRIOR_AUTHORIZATION_TYPE
        ,' 
		+ @GPI + ' AS GPI_TRUNC
        ,' + @GPICount + ' AS GPI_COUNT
		--,PLAN_FORM.DRUG_TYPE_LABEL
		--,PLAN_FORM.LIMITED_ACCESS_YN
		,YEAR(PLAN_FORM.EFFECTIVE_DATE) AS YEAR_EFFECTIVE_DATE
		,LEFT(DATENAME(MONTH,PLAN_FORM.EFFECTIVE_DATE),3) AS MONTH_EFFECTIVE_DATE
        ,FRF.FORMULARY_TYPE
        ,(SELECT CASE WHEN FRF.FORMULARY_ID = ''PARTD'' OR ''' + @NDCBlankFlag + ''' = ''Y'' THEN ''YES'' ELSE ''NO'' END AS PART_D_COVERED 
		FROM RX_NDC_DRUGS DRUGS 
			left JOIN PLAN_DRUG_FORMULARY PLAN_FORM ON DRUGS.GNPR_ID LIKE '''' + PLAN_FORM.GPI_10_ID + ''%'' + '''' AND DRUGS.DRUG_FORM = PLAN_FORM.DRUG_FORM
						AND DRUGS.DRUG_ROUTE = PLAN_FORM.DRUG_ROUTE AND DRUGS.DRUG_OTC_FLAG = PLAN_FORM.DRUG_OTC_FLAG AND DRUGS.DRUG_GENERIC_FLAG = PLAN_FORM.DRUG_GENERIC_FLAG 
						AND PLAN_FORM.FORMULARY_ID = ''PARTD''  AND YEAR(EFFECTIVE_DATE) = ''' + @pFormularyYear + 
		'''
			LEFT OUTER JOIN PLAN_HPMS_FORMULARY_SUBMISSIONS FRF ON PLAN_FORM.THERAPEUTIC_CATEGORY_NAME = FRF.THERAPEUTIC_CATEGORY_NAME AND FRF.FORMULARY_ID = ''PARTD'' AND
						PLAN_FORM.THERAPEUTIC_CLASS_NAME = FRF.THERAPEUTIC_CLASS_NAME AND PLAN_FORM.RELATED_NDC = FRF.RELATED_NDC AND FRF_YEAR = ''' + @pFormularyYear + '''
			LEFT JOIN (SELECT CODE,CODE_DESC,CODE_TYPE_DESC AS DRUG_ROUTE_LABEL FROM SUP_SUPPORT_CODE WHERE CODE_TYPE = ''DRUG_FORM'') C ON DRUGS.DRUG_FORM = CODE AND DRUGS.DRUG_ROUTE = CODE_DESC
			WHERE' + @WhereCondition + ') AS PART_D_COVERED '
	SET @SQL = @SQL + '
		,(SELECT CASE WHEN FRF.FORMULARY_ID = ''SPECD'' OR ''' + @NDCBlankFlag + ''' = ''Y'' THEN ''YES'' ELSE ''NO'' END AS PART_D_COVERED 
		FROM RX_NDC_DRUGS DRUGS 
			left JOIN PLAN_DRUG_FORMULARY PLAN_FORM ON DRUGS.GNPR_ID LIKE '''' + PLAN_FORM.GPI_10_ID + ''%'' + '''' AND DRUGS.DRUG_FORM = PLAN_FORM.DRUG_FORM
						AND DRUGS.DRUG_ROUTE = PLAN_FORM.DRUG_ROUTE AND DRUGS.DRUG_OTC_FLAG = PLAN_FORM.DRUG_OTC_FLAG AND DRUGS.DRUG_GENERIC_FLAG = PLAN_FORM.DRUG_GENERIC_FLAG 
						AND PLAN_FORM.FORMULARY_ID = ''SPECD''  AND YEAR(EFFECTIVE_DATE) = ''' + @pFormularyYear + '''
			LEFT OUTER JOIN PLAN_HPMS_FORMULARY_SUBMISSIONS FRF ON PLAN_FORM.THERAPEUTIC_CATEGORY_NAME = FRF.THERAPEUTIC_CATEGORY_NAME AND FRF.FORMULARY_ID = ''SPECD'' AND
						PLAN_FORM.THERAPEUTIC_CLASS_NAME = FRF.THERAPEUTIC_CLASS_NAME AND PLAN_FORM.RELATED_NDC = FRF.RELATED_NDC AND FRF_YEAR = ''' + @pFormularyYear + 
		'''
			LEFT JOIN (SELECT CODE,CODE_DESC,CODE_TYPE_DESC AS DRUG_ROUTE_LABEL FROM SUP_SUPPORT_CODE WHERE CODE_TYPE = ''DRUG_FORM'') C ON DRUGS.DRUG_FORM = CODE AND DRUGS.DRUG_ROUTE = CODE_DESC
			WHERE' + @WhereCondition + ') AS SPECD_COVERED '
	SET @SQL = @SQL + '
		,(SELECT CASE WHEN FRF.FORMULARY_ID = ''PROTD'' OR ''' + @NDCBlankFlag + ''' = ''Y'' THEN ''YES'' ELSE ''NO'' END AS PROTD_COVERED 
		FROM RX_NDC_DRUGS DRUGS 
			left JOIN PLAN_DRUG_FORMULARY PLAN_FORM ON DRUGS.GNPR_ID LIKE '''' + PLAN_FORM.GPI_10_ID + ''%'' + '''' AND DRUGS.DRUG_FORM = PLAN_FORM.DRUG_FORM
						AND DRUGS.DRUG_ROUTE = PLAN_FORM.DRUG_ROUTE AND DRUGS.DRUG_OTC_FLAG = PLAN_FORM.DRUG_OTC_FLAG AND DRUGS.DRUG_GENERIC_FLAG = PLAN_FORM.DRUG_GENERIC_FLAG 
						AND PLAN_FORM.FORMULARY_ID = ''PROTD''  AND YEAR(EFFECTIVE_DATE) = ''' + @pFormularyYear + '''
			LEFT OUTER JOIN PLAN_HPMS_FORMULARY_SUBMISSIONS FRF ON PLAN_FORM.THERAPEUTIC_CATEGORY_NAME = FRF.THERAPEUTIC_CATEGORY_NAME AND FRF.FORMULARY_ID = ''PROTD'' AND
						PLAN_FORM.THERAPEUTIC_CLASS_NAME = FRF.THERAPEUTIC_CLASS_NAME AND PLAN_FORM.RELATED_NDC = FRF.RELATED_NDC AND FRF_YEAR = ''' + @pFormularyYear + 
		'''
			LEFT JOIN (SELECT CODE,CODE_DESC,CODE_TYPE_DESC AS DRUG_ROUTE_LABEL FROM SUP_SUPPORT_CODE WHERE CODE_TYPE = ''DRUG_FORM'') C ON DRUGS.DRUG_FORM = CODE AND DRUGS.DRUG_ROUTE = CODE_DESC
			WHERE' + @WhereCondition + ') AS PROTD_COVERED '
	SET @SQL = @SQL + '
	FROM RX_NDC_DRUGS DRUGS 
	left JOIN PLAN_DRUG_FORMULARY PLAN_FORM ON DRUGS.GNPR_ID LIKE '''' + PLAN_FORM.GPI_10_ID + ''%'' + '''' AND DRUGS.DRUG_FORM = PLAN_FORM.DRUG_FORM
				AND DRUGS.DRUG_ROUTE = PLAN_FORM.DRUG_ROUTE AND DRUGS.DRUG_OTC_FLAG = PLAN_FORM.DRUG_OTC_FLAG AND DRUGS.DRUG_GENERIC_FLAG = PLAN_FORM.DRUG_GENERIC_FLAG 
				AND PLAN_FORM.FORMULARY_ID = ''' + @pFormularyName + '''  AND YEAR(EFFECTIVE_DATE) = ''' + @pFormularyYear + '''
	LEFT OUTER JOIN PLAN_HPMS_FORMULARY_SUBMISSIONS FRF ON PLAN_FORM.THERAPEUTIC_CATEGORY_NAME = FRF.THERAPEUTIC_CATEGORY_NAME AND FRF.FORMULARY_ID = ''' + @pFormularyName + ''' AND
				PLAN_FORM.THERAPEUTIC_CLASS_NAME = FRF.THERAPEUTIC_CLASS_NAME AND PLAN_FORM.RELATED_NDC = FRF.RELATED_NDC AND FRF_YEAR = ''' + @pFormularyYear + '''
	LEFT JOIN (SELECT CODE,CODE_DESC,CODE_TYPE_DESC AS DRUG_ROUTE_LABEL FROM SUP_SUPPORT_CODE WHERE CODE_TYPE = ''DRUG_FORM'') C ON DRUGS.DRUG_FORM = CODE AND DRUGS.DRUG_ROUTE = CODE_DESC
	WHERE' + @WhereCondition + 
		' 
	ORDER BY FRF.EFFECTIVE_DATE DESC'

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

PRINT N'Creating [dbo].[PDE_FIR_POP_NOTES_INSERT]'
GO

CREATE PROCEDURE [dbo].[PDE_FIR_POP_NOTES_INSERT] @pMemberID VARCHAR(50) = ''
	,@pUpdatePerson VARCHAR(100) = ''
	,@pComments NVARCHAR(max) = ''
	,@pUpdateTime DATETIME = ''
	,@ErrorMessage VARCHAR(255) = '' OUTPUT
AS
BEGIN
	SET NOCOUNT ON

	--internal SP parameter
	DECLARE @MemberID NVARCHAR(50) = ''
		,@UpdateTime DATETIME = GETDATE()

	PRINT @UpdateTime

	IF NOT (
			@pComments IS NULL
			OR @pComments = ''
			)
	BEGIN
		PRINT 'entering comment loop'
		PRINT @pUpdatePerson

		SELECT @UpdateTime

		SELECT @pComments

		INSERT INTO dbo.PDE_FIR_POP_NOTES (
			MEMBER_ID
			,UPDATE_STATUS_PERSON
			,UPDATE_STATUS_DATE
			,NOTES
			)
		VALUES (
			@pMemberId
			,@pUpdatePerson
			,@UpdateTime
			,@pComments
			)
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

PRINT N'Creating [dbo].[PDE_REC_MEMBER_DETAILS_NOTES]'
GO

SET QUOTED_IDENTIFIER OFF
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- Build by PJ
-- =============================================
CREATE PROCEDURE [dbo].[PDE_REC_MEMBER_DETAILS_NOTES] @pKey NVARCHAR(30) = ''
	,@pStatus NVARCHAR(10) = ''
	,@pAccuYear NVARCHAR(4) = ''
	,@pFirstErrorOnly VARCHAR(1) = ''
	,@pProductID NVARCHAR(10) = NULL
	,@pGroupField NVARCHAR(100) = ''
	,@pGroupValue NVARCHAR(max) = ''
	,@pFieldName VARCHAR(8000) = ''
	,@pMonth NVARCHAR(2) = ''
AS
BEGIN
	DECLARE @WhereCondition NVARCHAR(500)
		,@SQL NVARCHAR(max) = ''
		,@MemberID NVARCHAR(50) = ''
		,@ClaimID NVARCHAR(25) = ''
		,@StartDate DATETIME
		,@EndDate DATETIME
		,@FromStatement NVARCHAR(max) = ''
		,@FindDistinctClaims NVARCHAR(max) = ''
		,@FieldName NVARCHAR(50) = ''

	IF @pStatus = 'ACC'
		OR @pStatus = 'INF'
		SET @WhereCondition = '  WHERE A.STATUS IN (''ACC'',''INF'', ''CLN'') and CLAM_CURRENT_STATUS IN (''P'',''A'',''D'') '

	IF @pStatus IS NULL
		OR @pStatus = ''
		SET @WhereCondition = ' WHERE A.STATUS IS NULL '

	IF @pStatus = 'REJ'
		SET @WhereCondition = ' WHERE A.STATUS = ''' + @pStatus + ''' '

	IF @pAccuYear IS NULL
		OR @pAccuYear = ''
		SET @pAccuYear = '2015'
	SET @ClaimID = @pKey

	--Supply default parameter value to allow proc to run and return results with no parameters specified
	IF @ClaimID IS NULL
		OR @ClaimID = ''
		SET @ClaimID = N'1918630'
	SET @MemberID = (
			SELECT RX_MEME_ID
			FROM RX_CLAIMS
			WHERE CLAM_ID = @ClaimID
			)

	--Build From Statement
	IF @pStatus <> 'REJ'
		SET @FromStatement = 'dbo.RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA A
				JOIN RX_CLAIMS B ON A.CLAIM_ID = B.CLAM_ID AND A.PDE_SEQ = B.PDE_SEQ'
	ELSE
	BEGIN
		SET @FromStatement = CASE 
				WHEN upper(@pFirstErrorOnly) = 'Y'
					THEN ' dbo.RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA A
			JOIN RX_CLAIMS B ON A.CLAIM_ID = B.CLAM_ID --AND A.PDE_SEQ = B.PDE_SEQ
			LEFT join RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA_GAP C ON A.CLAIM_ID = C.CLAM_ID AND A.PDE_SEQ = C.PDE_SEQ
			JOIN MB_ENROLLEE_INFO D ON B.RX_MEME_ID = D.MEMBER_ID
			LEFT JOIN RX_NDC_DRUGS E ON B.DRUG_NDC_CODE = E.DRUG_NDC_CODE
			JOIN dbo.RX_CMS_PDED_DETAIL_ERROR_CODE PDEDD ON A.CLAIM_ID=PDEDD.CLAIM_ID AND A.ERROR_SUBMISSION_NUM = PDEDD.ERROR_SUBMISSION_NUM AND SUBSTRING(A.ERROR_CODE,1,3) = PDEDD.ERROR_CODE
			JOIN dbo.PDE_REJECT_CODE PDER on PDEDD.ERROR_CODE = PDER.ERROR_CODE'
				ELSE ' dbo.RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA A
			INNER JOIN RX_CLAIMS B ON A.CLAIM_ID = B.CLAM_ID --AND A.PDE_SEQ = B.PDE_SEQ 
			LEFT join RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA_GAP C ON A.CLAIM_ID = C.CLAM_ID AND A.PDE_SEQ = C.PDE_SEQ
			JOIN MB_ENROLLEE_INFO D ON B.RX_MEME_ID = D.MEMBER_ID
			LEFT JOIN RX_NDC_DRUGS E ON B.DRUG_NDC_CODE = E.DRUG_NDC_CODE
			INNER JOIN dbo.RX_CMS_PDED_DETAIL_ERROR_CODE PDEDD ON A.CLAIM_ID=PDEDD.CLAIM_ID
			INNER JOIN dbo.PDE_REJECT_CODE PDER ON PDEDD.ERROR_CODE = PDER.ERROR_CODE AND A.ERROR_SUBMISSION_NUM = PDEDD.ERROR_SUBMISSION_NUM'
				END
	END

	--IN Acc/Out Page, filter on selected field Name.
	IF @pFieldName <> 'ALL'
		AND @pStatus IN (
			'ACC'
			,''
			)
	BEGIN
		--EX. Select 'OTC' from 'OTC_COUNT'
		SET @FieldName = (
				SELECT SUBSTRING(@pFieldName, 1, patindex('%[_]%', @pFieldName) - 1)
				)
		SET @WhereCondition = @WhereCondition + ' AND ' + CASE 
				WHEN @FieldName = 'OTC'
					THEN ' DRUG_COVERAGE_STATUS_CODE = ''O'''
				WHEN @FieldName = 'ENHANCED'
					THEN ' DRUG_COVERAGE_STATUS_CODE = ''E'''
				WHEN @FieldName = 'COVERED'
					THEN ' DRUG_COVERAGE_STATUS_CODE = ''C'''
				WHEN (
						@FieldName <> 'OTC'
						AND @FieldName <> 'ENHANCED'
						AND @FieldName <> 'COVERED'
						)
					THEN ' A.' + @FieldName + ' <> 0 '
				END + ' '
	END

	IF NOT (
			@pMonth IS NULL
			OR @pMonth = ''
			)
		SET @WhereCondition = @WhereCondition + ' AND MONTH(A.PAID_DT) = ''' + @pMonth + ''''
	--- PJ: Passing member id to the where clause for query @FindDistinctClaims
	SET @WhereCondition = @WhereCondition + ' AND B.RX_MEME_ID = ''' + @MemberID + ''' AND  DRUG_COVERAGE_STATUS_CODE IN (''C'',''E'',''O'')  '

	IF @pStatus = 'REJ'
		SET @WhereCondition = @WhereCondition + ' AND CLAM_CURRENT_STATUS IN (''P'') AND CLAM_IS_REVERSED = ''N'' '
	SET @StartDate = @pAccuYear + '-01-01'
	SET @EndDate = @pAccuYear + '-12-31'
	SET @WhereCondition = @WhereCondition + ' AND PAID_DT BETWEEN ''' + CONVERT(VARCHAR(10), @StartDate, 101) + ''' AND ''' + CONVERT(VARCHAR(10), @EndDate, 101) + ''' '

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
	SET @SQL = 'SELECT CLAM_ID,UPDATE_STATUS_DATE,
  ''=#''+cast(UPDATE_STATUS_DATE AS NVARCHAR)+''#=''+''=#by ''+cast(UPDATE_STATUS_PERSON AS NVARCHAR)+''#=''+''=#''+CAST(NOTES AS NVARCHAR(MAX)) +''#='' AS [KEY] 
 	FROM dbo.PDE_REC_NOTES_REJ
	WHERE MEMBER_ID = ''' + @MemberID + ''' 
	ORDER BY UPDATE_STATUS_DATE'

	PRINT @SQL

	INSERT INTO #tempNotes
	EXEC sp_executesql @SQL

	--second formated table
	CREATE TABLE #formatedTemp (
		CLAIM_ID BIGINT
		,[KEY] NVARCHAR(max)
		)

	--query puts notes in a single string from the previous table
	SET @SQL = N'SELECT DISTINCT
ST2.CLAIM_ID
,STUFF((SELECT '','' + [KEY] 
        FROM #tempNotes ST1
        WHERE ST1.CLAIM_ID = ST2.CLAIM_ID
        ORDER BY ST1.CLAIM_ID, ST1.DATE
        FOR XML PATH('''')),1,1,'''')
FROM #tempNotes ST2 '

	INSERT INTO #formatedTemp
	EXEC sp_executesql @SQL

	PRINT @SQL

	-- Create a temporary table with the distinct claims to join on the for the member.
	SET @FindDistinctClaims = 'SELECT CLAM_ID,[ORDER], CLAM_ORIGINAL_ENTRY_DATE FROM 
							( SELECT B.CLAM_ID
							,ROW_NUMBER() OVER(PARTITION BY B.CLAM_ID ORDER BY CLAM_ORIGINAL_ENTRY_DATE) AS RN
							,ROW_NUMBER() OVER(ORDER BY CLAM_ORIGINAL_ENTRY_DATE) AS [ORDER]
							,CLAM_ORIGINAL_ENTRY_DATE
							,CLAM_FILL_DATE
							,B.TGCDCA
					 FROM ' + @FromStatement + '
					' + @WhereCondition + ' ) 
					 Claims WHERE RN = 1
					 ORDER BY CLAM_ORIGINAL_ENTRY_DATE,CLAM_FILL_DATE,TGCDCA,CLAM_ID
					 '

	CREATE TABLE #DistinctClaims (
		CLAM_ID BIGINT
		,[ORDER] INT
		,CLAM_ORIGINAL_ENTRY_DATE DATETIME
		)

	INSERT INTO #DistinctClaims
	EXEC sp_executesql @FindDistinctClaims --, N'@pPDE_STAT nvarchar(75)', @pPDE_STAT  = @pStatus

	PRINT @FindDistinctClaims

	SET @SQL = N'SELECT  Claims.CLAM_ID,
[KEY] AS NOTES 
FROM #DistinctClaims Claims
LEFT OUTER JOIN #formatedTemp NOTES ON Claims.CLAM_ID = NOTES.CLAIM_ID
order by CLAM_ORIGINAL_ENTRY_DATE'

	PRINT cast(@SQL AS TEXT)

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

PRINT N'Creating [dbo].[PDE_FIR_POP_SUMMARY_NOTES]'
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PDE_FIR_POP_SUMMARY_NOTES] (
	@pAccuYear VARCHAR(4) = ''
	,@pFieldName VARCHAR(50) = ''
	,@pFirStatus VARCHAR(10) = ''
	,@pMonth VARCHAR(2) = ''
	,@pMemberID VARCHAR(25) = ''
	,@pProductID NVARCHAR(10) = NULL
	,@pSQL NVARCHAR(max) = '' OUTPUT
	)
AS
BEGIN
	DECLARE @pWhereCondition VARCHAR(4000) = ''
		,@TransferInOrOut VARCHAR(10) = ''
		,@FromStatement NVARCHAR(max) = ''
		,@SQL NVARCHAR(max) = ''
	--select plan id's
	DECLARE @planID VARCHAR(8000)

	SELECT @planID = COALESCE(@planID + ''','' ', '') + CODE
	FROM SUP_SUPPORT_CODE
	WHERE CODE_TYPE = 'PLAN_ID'
		AND CODE IS NOT NULL

	--set default value
	SET @TransferInOrOut = CASE 
			WHEN @pFirStatus = 'In'
				THEN 'F2'
			ELSE 'F1'
			END

	DECLARE @Outstanding VARCHAR(2500) = '((ISNULL(t.TRANSACTION_CODE,'''') <> ''' + @TransferInOrOut + '''  and not (e.PRE_AFTER_PLAN_ID IS NULL OR e.PRE_AFTER_PLAN_ID = '''') )) '
		,@Received VARCHAR(2500) = '(t.TRANSACTION_CODE = ''' + @TransferInOrOut + '''' + ' AND YEAR(t.TERMINATION_DATE) = ''' + @pAccuYear + '''' + ')'
		,@Required VARCHAR(2500) = '(t.TRANSACTION_CODE = ''' + @TransferInOrOut + '''  OR (ISNULL(t.TRANSACTION_CODE,'''') = ''''   and not (e.PRE_AFTER_PLAN_ID IS NULL OR e.PRE_AFTER_PLAN_ID = '''') ))'
		,@Errors VARCHAR(2500) = ' (t.FIR_APPLIED_TO_CLAIM = ''F'' )'

	IF @pAccuYear IS NULL
		OR @pAccuYear = ''
		SET @pAccuYear = YEAR(GETDATE())

	IF @pFirStatus IS NULL
		OR @pFirStatus = ''
		SET @pFirStatus = 'In'

	IF @pFieldName IS NULL
		OR @pFieldName = ''
		SET @pFieldName = 'RECEIVED_FIR'

	IF @pMemberID IS NULL
		OR @pMemberID = ''
		SET @pMemberID = '20010900124700'
	SET @pWhereCondition = CASE 
			WHEN @pFirStatus = 'In'
				THEN ' TRANSACTION_TYPE in (''NE'',''RI'') AND TRANSACTION_VOID_IND=''N'' '
			WHEN @pFirStatus = 'Out'
				THEN ' TRANSACTION_TYPE=''TM'' AND TRANSACTION_VOID_IND=''N'' '
			END
	SET @pWhereCondition = @pWhereCondition + ' AND YEAR(e.PRODUCT_EFF_DATE) = ''' + @pAccuYear + ''' ' + ' and (e.PRE_AFTER_PLAN_ID NOT IN (''' + @planID + '''' + ') or e.PRE_AFTER_PLAN_ID is null or e.PRE_AFTER_PLAN_ID  = '''') '
	SET @pWhereCondition = @pWhereCondition + ' AND ' + CASE 
			WHEN @pFieldName = 'RECEIVED_FIR'
				AND @pFirStatus = 'In'
				THEN @Received
			WHEN @pFieldName = 'REQUIRED_FIR'
				AND @pFirStatus = 'In'
				THEN @Required
			WHEN @pFieldName = 'RECEIVED_FIR'
				AND @pFirStatus = 'Out'
				THEN @Received
			WHEN @pFieldName = 'REQUIRED_FIR'
				AND @pFirStatus = 'Out'
				THEN @Required
			WHEN @pFieldName = 'OUTSTANDING_FIR'
				THEN @Outstanding
			WHEN @pFieldName = 'ENROLLEMENT'
				THEN ' m.MEMBER_ID IS NOT NULL '
			WHEN @pFieldName = 'TROOP'
				THEN ' t.APPLIED_TROOP_AMOUNT  IS NOT NULL '
			WHEN @pFieldName = 'COST'
				THEN ' t.APPLIED_DRUG_COST IS NOT NULL'
			WHEN @pFieldName = 'ERRORS'
				THEN @Errors
			END
	SET @pWhereCondition = @pWhereCondition + ' AND m.MEMBER_ID = ''' + @pMemberID + ''' '

	IF @pMonth <> ''
		SET @pWhereCondition = @pWhereCondition + ' AND MONTH(e.PRODUCT_EFF_DATE) = ''' + @pMonth + ''' '
	SET @FromStatement = ' SELECT MEMBER_ID FROM (SELECT DISTINCT m.MEMBER_ID AS MEMBER_ID,' + CASE 
			WHEN @pFirStatus = 'Out'
				THEN 'PRODUCT_EFF_DATE AS PRODUCT_EFF_DATE'
			WHEN @pFirStatus = 'In'
				THEN 'PRODUCT_EFF_DATE'
			END + ' from MB_MEMBER_PRODUCTS e
	left join RX_BALANCE_TRANSFER t on e.MEMBER_CK = t.MEMBER_CK AND YEAR(t.TERMINATION_DATE) = ''' + @pAccuYear + ''' and e.PLAN_ID = t.PLAN_ID and t.TRANSACTION_CODE = ''' + @TransferInOrOut + ''' 
    RIGHT JOIN MB_ENROLLEE_INFO m ON e.MEMBER_CK=m.MEMBER_CK
    left join [SUP_P2P_PLAN_NAME] f ON e.PRE_AFTER_PLAN_ID = f.CONTRACT_ID
    WHERE ' + @pWhereCondition + ' 
	) DATA
	ORDER BY YEAR(PRODUCT_EFF_DATE), MONTH(PRODUCT_EFF_DATE), MEMBER_ID'

	--print @pSQL
	--exec sp_executesql @FromStatement
	--I wanted to make this easily eitable, so i built two temporary tables to format notes into a single variable
	--rather than putting a nested query into the select statement
	--in the first query, we gather all notes for a member,
	--in the second query, we concate the notes into a single string
	CREATE TABLE #tempNotes (
		MEMBER_ID BIGINT
		,[DATE] DATETIME
		,[KEY] NVARCHAR(max)
		)

	--select notes, update temp table
	SET @SQL = 'SELECT MEMBER_ID,UPDATE_STATUS_DATE,
  ''=#''+cast(UPDATE_STATUS_DATE AS NVARCHAR)+''#=''+''=#by ''+cast(UPDATE_STATUS_PERSON AS NVARCHAR)+''#=''+''=#''+CAST(NOTES AS NVARCHAR(MAX)) +''#='' AS [KEY] 
 	FROM dbo.PDE_FIR_POP_NOTES
	WHERE MEMBER_ID = ''' + @pMemberID + ''' 
	ORDER BY UPDATE_STATUS_DATE'

	--print @SQL
	INSERT INTO #tempNotes
	EXEC sp_executesql @SQL

	--	PRINT @SQL
	--second formated table
	CREATE TABLE #formatedTemp (
		MEMBER_ID BIGINT
		,[KEY] NVARCHAR(max)
		)

	--query puts notes in a single string from the previous table
	SET @SQL = ' Select distinct ST2.MEMBER_ID,
    substring(
        (
            Select '',''+ST1.[KEY]  AS [text()]
            From dbo.#tempNotes ST1
            Where ST1.MEMBER_ID  = ST2.MEMBER_ID 
            ORDER BY ST1.MEMBER_ID,ST1.DATE 
            For XML PATH ('''')' +
		--SubString is activated, 2,10000
		'        ), 2, 10000) [#tempNotes]
From dbo.#tempNotes ST2'

	INSERT INTO #formatedTemp
	EXEC sp_executesql @SQL

	--PRINT @SQL
	CREATE TABLE #dataset (MEMBER_ID BIGINT)

	INSERT INTO #dataset
	EXEC sp_executesql @FromStatement

	SET @SQL = N'SELECT  DATA.MEMBER_ID,
[KEY] AS NOTES 
FROM
#dataset DATA
LEFT JOIN #formatedTemp NOTES ON DATA.MEMBER_ID = NOTES.MEMBER_ID
'

	--PRINT cast(@SQL as text) 
	EXEC sp_executesql @SQL

	DROP TABLE #tempNotes

	DROP TABLE #formatedTemp

	DROP TABLE #dataset
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

PRINT N'Altering [dbo].[PDE_REC_CLAIM_DETAILS_ACC]'
GO

ALTER PROCEDURE [dbo].[PDE_REC_CLAIM_DETAILS_ACC] (
	@pKey VARCHAR(50) = ''
	,@pPdeStatus VARCHAR(10) = ''
	,@pProductID NVARCHAR(10) = NULL
	,@pMonth NVARCHAR(2) = ''
	,@pFirstErrorOnly VARCHAR(1) = ''
	,@pSQL NVARCHAR(max) = '' OUTPUT
	)
AS
BEGIN
	DECLARE @pWhereCondition NVARCHAR(max) = ''
		,@pFromStatement NVARCHAR(max) = ''
		,@JoinParameter NVARCHAR(1000) = ''
		,@PbmID NVARCHAR(50) = ''
		,@ClaimID NVARCHAR(50) = ''

	SET @ClaimID = @pKey

	--SET DEFAULT PARAMETERS
	IF @ClaimID IS NULL
		OR @ClaimID = ''
		SET @ClaimID = '1826937'
	SET @pWhereCondition = 'A.CLAIM_ID = ''' + @ClaimID + ''' AND DRUG_COVERAGE_STATUS_CODE IN (''C'',''E'',''O'') AND ( A.STATUS = ''ACC'' OR A.STATUS = ''INF'' OR A.STATUS = ''CLN'')'
	--Set columns for select statement
	SET @pSQL = 
		'SELECT B.RX_MEME_ID AS MEMBER_ID,
			MEMBER_NAME,
			CLAM_CHECK_REFERENCE_NUMBER AS [PBM_ID], 
			RIGHT(CSPI_ID,1) as [LICS_TIER],
			CASE WHEN BSDL_MCTR_TYPE = 0 THEN CLAM_DRUG_TYPE ELSE BSDL_MCTR_TYPE END as [DRUG_TIER],
			E.DRUG_NDC_CODE as DRUG_NDC,
			A.STATUS,
			CLAM_ORIGINAL_ENTRY_DATE AS PAID_DT,
		   (CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (INGREDIENT_COST_PAID+DISPENSING_FEE_PAID)  
			ELSE  (0 - (INGREDIENT_COST_PAID+DISPENSING_FEE_PAID)) END) AS [COST],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (A.PATIENT_PAY_AMOUNT)  
			ELSE  (0 - (A.PATIENT_PAY_AMOUNT)) END) AS [COPAY],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (A.LICS)  
			ELSE  (0 - (A.LICS)) END) AS [LICS],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (GDCB)  
			ELSE  (0 - (GDCB)) END) AS [GDCB],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (A.CPP)  
			ELSE  (0 - (A.CPP)) END) AS [CPP],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (PLRO)  
			ELSE  (0 - (PLRO)) END) AS [PLRO],
			E.DRUG_NAME,
			FILL_DT,
			A.TGCDCA AS TGCDCA,
			A.TrOOPA AS TROOPA,
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (CGDP)  
			ELSE  (0 - (CGDP)) END) AS [CGDP],
			(GDCA)  AS [GDCA],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (A.NPP)  
			ELSE  (0 - (A.NPP)) END) AS [NPP],'
	SET @pSQL = @pSQL + '
			(P_LEVEL_P1)  AS [COPAY_DEDUCT],
			(P_LEVEL_P2)  AS [COPAY_COV],
			(P_LEVEL_P3)  AS [COPAY_GAP],
			(P_LEVEL_P4)  AS [COPAY_CAT],
			(P_LEVEL1) AS [COST_DEDUCT],
			(P_LEVEL2) AS [COST_COV],
			(P_LEVEL3) AS [COST_GAP],
			(P_LEVEL4) AS [COST_CAT],
			(P_LEVEL_P1+P_LEVEL_P2+P_LEVEL_P3+P_LEVEL_P4) AS [COPAY_TOT],
			(P_LEVEL1+P_LEVEL2+P_LEVEL3+P_LEVEL4) AS [COST_TOTAL],
			(C.LICS) AS PBM_LICS,
			''0.00'' AS LICS_FAKE,
			ADJUSTMENT_DELETE_CODE'
	SET @pSQL = @pSQL + '
				FROM dbo.RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA A
			JOIN RX_CLAIMS B ON A.CLAIM_ID = B.CLAM_ID AND A.PDE_SEQ = B.PDE_SEQ
			LEFT JOIN RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA_GAP C ON A.CLAIM_ID = C.CLAM_ID AND A.PDE_SEQ = C.PDE_SEQ
			JOIN MB_ENROLLEE_INFO D ON B.RX_MEME_ID = D.MEMBER_ID
			LEFT JOIN RX_NDC_DRUGS E ON B.DRUG_NDC_CODE = E.DRUG_NDC_CODE
				WHERE ' + @pWhereCondition + '
				order by CLAM_ORIGINAL_ENTRY_DATE'

	PRINT @pSQL

	EXEC sp_executesql @pSQL
		,N'@pDyanmicStatusVariable nvarchar(75)'
		,@pDyanmicStatusVariable = @pPdeStatus
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

PRINT N'Altering [dbo].[PDE_MEMBER_INFO_DETAILS]'
GO

SET QUOTED_IDENTIFIER OFF
GO

-- =============================================
-- Author:		
-- Create date: 3/2/2015
-- Description:	
-- =============================================
ALTER PROCEDURE [dbo].[PDE_MEMBER_INFO_DETAILS] @pMemberID NVARCHAR(50) = NULL
	,@pAccuYear NVARCHAR(4) = ''
	,@pDataLimit NVARCHAR(10) = ''
	,@pOffSet NVARCHAR(10) = ''
	,@pSQL NVARCHAR(4000) = '' OUTPUT
AS
BEGIN
	DECLARE @WhereCondition NVARCHAR(MAX) = ''
		,@OffsetText NVARCHAR(1000) = ''

	IF @pMemberID IS NULL
		OR @pMemberID = ''
		SET @pMemberID = '20000800307200'

	IF @pAccuYear IS NULL
		OR @pAccuYear = ''
		SET @pAccuYear = '2014'
	SET @WhereCondition = 'A.RX_MEME_ID IN (''' + @pMemberID + ''') AND YEAR(A.CLAM_FILL_DATE) = ''' + @pAccuYear + ''''

	-- Setting offset and data limit
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

	SET @pSQL = 
		'SELECT 	
			CLAM_ORIGINAL_ENTRY_DATE AS PAID_DATE
			,CASE WHEN ADJUSTMENT_DELETE_CODE <> ''D'' THEN B.LICS ELSE -B.LICS END AS LICS
			,CASE WHEN B.STATUS IS NULL THEN ''OUT'' ELSE B.STATUS END AS CURRENT_STATUS 
			,FILL_DT as DATE
			,PLAN_ID
			,PBP
			,RIGHT(CSPI_ID,1) as [LICS_TIER]
			,CASE WHEN BSDL_MCTR_TYPE = 0 THEN CLAM_DRUG_TYPE ELSE BSDL_MCTR_TYPE END as [TIER]
			,A.RX_MEME_ID AS MEMBER_ID
			,CLAM_CHECK_REFERENCE_NUMBER AS CLAIM_ID
			,A.CLAM_ID
			,B.TGCDCA
			,B.TrOOPA
			,C.COST_ACCU AS CADRE_TGCDCA
			,C.TROOP_ACCU AS CADRE_TROOPA
			,CASE WHEN ADJUSTMENT_DELETE_CODE <> ''D'' THEN B.CPP ELSE -B.CPP END AS CPP
			,CASE WHEN ADJUSTMENT_DELETE_CODE <> ''D'' THEN B.NPP ELSE -B.NPP END AS NPP
			,G.P_LEVEL_P1+G.P_LEVEL_P2+G.P_LEVEL_P3+G.P_LEVEL_P4 as COPAY
			,DRUG_COVERAGE_STATUS_CODE
			,A.DRUG_NDC_CODE
			,CASE WHEN ADJUSTMENT_DELETE_CODE <> ''D'' THEN PLRO ELSE -PLRO END AS PLRO
			,BATCH_DATE
			,CASE WHEN ADJUSTMENT_DELETE_CODE <> ''D'' THEN PATIENT_PAY_AMOUNT ELSE -PATIENT_PAY_AMOUNT END AS PATIENT_PAY_AMOUNT
			,CASE WHEN ADJUSTMENT_DELETE_CODE <> ''D'' THEN OTHER_TROOP ELSE OTHER_TROOP END AS OTHER_TROOP
			,DRUG_NAME
			,CASE WHEN ADJUSTMENT_DELETE_CODE <> ''D'' THEN B.GDCB ELSE -B.GDCB END AS GDCB
			,CASE WHEN ADJUSTMENT_DELETE_CODE <> ''D'' THEN B.GDCA ELSE -B.GDCA END AS GDCA
			,(CASE WHEN ADJUSTMENT_DELETE_CODE <> ''D'' THEN B.INGREDIENT_COST_PAID + B.DISPENSING_FEE_PAID ELSE  -1 * (B.INGREDIENT_COST_PAID + B.DISPENSING_FEE_PAID ) end ) AS DRUG_COST
			,(CASE WHEN B.STATUS = ''ACC'' OR B.STATUS = ''INF'' THEN ''Y'' ELSE '''' END) AS FLAG_ACCEPTED   
			,(CASE WHEN B.STATUS = ''REJ'' THEN ''Y'' ELSE '''' END) AS REJ   
			,CASE WHEN CLAM_IS_REVERSED = ''Y'' THEN ''R'' WHEN ADJUSTMENT_DELETE_CODE = ''D'' THEN ''D'' ELSE '''' END AS ADJUSTMENT_DELETE_CODE
			,(CASE WHEN G.P_LEVEL_P1+G.P_LEVEL_P2+G.P_LEVEL_P3+G.P_LEVEL_P4 <> C.P_LEVEL_P1+C.P_LEVEL_P2+C.P_LEVEL_P3+C.P_LEVEL_P4 THEN ''Y'' ELSE '''' END) AS DISMATCH
            ,CASE WHEN ADJUSTMENT_DELETE_CODE <> ''D'' THEN B.TROOP ELSE -B.TROOP END AS TROOP 
            ,CASE WHEN ADJUSTMENT_DELETE_CODE <> ''D'' THEN B.CGDP ELSE -B.CGDP END AS CGDP
	FROM RX_CLAIMS  A
	JOIN RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA B ON A.PDE_SEQ = B.PDE_SEQ AND A.CLAM_ID = B.CLAIM_ID 
	LEFT JOIN RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA_GAP G ON B.CLAIM_ID = G.CLAM_ID AND B.PDE_SEQ = G.PDE_SEQ
	LEFT JOIN RX_NDC_DRUGS E ON A.DRUG_NDC_CODE = E.DRUG_NDC_CODE
	LEFT JOIN RX_CLAIM_ACCU_LEVEL C ON A.CLAM_ID = C.CLAM_ID  AND C.STATUS IS NULL

	WHERE ' 
		+ @WhereCondition + ' and DRUG_COVERAGE_STATUS_CODE IN (''E'',''C'',''O'')
	ORDER BY CLAM_CURRENT_STATUS_DATE,A.CLAM_ORIGINAL_ENTRY_DATE'

	PRINT @pSQL

	EXECUTE sp_executesql @pSQL
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

PRINT N'Altering [dbo].[PDE_REC_CLAIM_DETAILS_MISMATCH]'
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[PDE_REC_CLAIM_DETAILS_MISMATCH] (
	@pClaimID VARCHAR(50) = ''
	,@pPdeStatus VARCHAR(10) = ''
	,@pProductID NVARCHAR(10) = NULL
	,@pMonth NVARCHAR(2) = ''
	,@pFirstErrorOnly VARCHAR(1) = ''
	,@pSQL NVARCHAR(max) = '' OUTPUT
	)
AS
BEGIN
	DECLARE @pWhereCondition NVARCHAR(max) = ''
		,@pFromStatement NVARCHAR(max) = ''
		,@JoinParameter NVARCHAR(1000) = ''
		,@PbmID NVARCHAR(50) = ''

	--SET DEFAULT PARAMETERS
	IF @pClaimID IS NULL
		OR @pClaimID = ''
		SET @pClaimID = '1826937'
	SET @pWhereCondition = 'A.CLAIM_ID = ''' + @pClaimID + ''' AND DRUG_COVERAGE_STATUS_CODE IN (''C'',''E'',''O'')'
	--Set columns for select statement
	SET @pSQL = 
		'SELECT B.RX_MEME_ID AS MEMBER_ID,
			MEMBER_NAME,
			A.STATUS,
			RIGHT(CSPI_ID,1) as [LICS_TIER],
			CASE WHEN BSDL_MCTR_TYPE = 0 THEN CLAM_DRUG_TYPE ELSE BSDL_MCTR_TYPE END as [DRUG_TIER],
			CLAM_CHECK_REFERENCE_NUMBER AS [PBM_ID], 
			E.DRUG_NDC_CODE as DRUG_NDC,
			CLAM_ORIGINAL_ENTRY_DATE AS PAID_DT,
		   (CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (INGREDIENT_COST_PAID+DISPENSING_FEE_PAID)  
			ELSE  (0 - (INGREDIENT_COST_PAID+DISPENSING_FEE_PAID)) END) AS [COST],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (A.PATIENT_PAY_AMOUNT)  
			ELSE  (0 - (A.PATIENT_PAY_AMOUNT)) END) AS [COPAY],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (A.LICS)  
			ELSE  (0 - (A.LICS)) END) AS [LICS],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (GDCB)  
			ELSE  (0 - (GDCB)) END) AS [GDCB],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (A.CPP)  
			ELSE  (0 - (A.CPP)) END) AS [CPP],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (PLRO)  
			ELSE  (0 - (PLRO)) END) AS [PLRO],
			E.DRUG_NAME,
			FILL_DT,
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (CGDP)  
			ELSE  (0 - (CGDP)) END) AS [CGDP],
			(GDCA)  AS [GDCA],
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>''D'' ) THEN  (A.NPP)  
			ELSE  (0 - (A.NPP)) END) AS [NPP],'
	SET @pSQL = @pSQL + '
			CLAM_TROOP,
			CLAM_GDCB,
			CLAM_GDCA,
			CLAM_LICS,
			CLAM_CPP,
			CLAM_CGDP,
			B.TGCDCA AS CLAM_TGCDCA,
			B.TROOPA AS CLAM_TROOPA,
			CLAM_COPAY_AMOUNT AS CLAM_COPAY,
			CLAM_MAX_AMOUNT AS CLAM_COST,
			ADJUSTMENT_DELETE_CODE'
	SET @pSQL = @pSQL + '
				FROM dbo.RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA A
			JOIN RX_CLAIMS B ON A.CLAIM_ID = B.CLAM_ID AND A.PDE_SEQ = B.PDE_SEQ
			JOIN MB_ENROLLEE_INFO D ON B.RX_MEME_ID = D.MEMBER_ID
			LEFT JOIN RX_NDC_DRUGS E ON B.DRUG_NDC_CODE = E.DRUG_NDC_CODE
				WHERE ' + @pWhereCondition + '
				order by CLAM_ORIGINAL_ENTRY_DATE'

	PRINT @pSQL

	EXEC sp_executesql @pSQL
		,N'@pDyanmicStatusVariable nvarchar(75)'
		,@pDyanmicStatusVariable = @pPdeStatus
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

PRINT N'Altering [dbo].[PDE_TRACKER_DETAILS]'
GO

ALTER PROCEDURE [dbo].[PDE_TRACKER_DETAILS]
	-- Add the parameters for the stored procedure here
	@pAccuYear NVARCHAR(4) = NULL
	,@pAccuMonth NVARCHAR(4) = NULL
	,@pProductID NVARCHAR(10) = NULL
	,@pBatchDate NVARCHAR(30) = NULL
	,@pFieldName NVARCHAR(40) = NULL
	,@pDataLimit NVARCHAR(10) = ''
	,@pOffSet NVARCHAR(10) = ''
	,@pSQL NVARCHAR(max) = '' OUTPUT
AS
BEGIN
	DECLARE @WhereCondition NVARCHAR(1000) = ''
		,@OffsetText NVARCHAR(1000) = ''
		--Done this way for easier, maintenance.  can just copy any corrections/additions to Details/Detailed data
		,@PdeTotal NVARCHAR(200) = ' NOT (ADJUSTMENT_DELETE_CODE = ''A'' OR ADJUSTMENT_DELETE_CODE = ''D'')  '
		,@PdeAcc NVARCHAR(200) = ' STATUS = ''ACC'' AND NOT (ADJUSTMENT_DELETE_CODE = ''A'' OR ADJUSTMENT_DELETE_CODE = ''D'') '
		,@PdeRej NVARCHAR(200) = ' STATUS = ''REJ'' AND NOT (ADJUSTMENT_DELETE_CODE = ''A'' OR ADJUSTMENT_DELETE_CODE = ''D'') '
		,@AdjTotal NVARCHAR(200) = ' ADJUSTMENT_DELETE_CODE = ''A''  '
		,@AdjAcc NVARCHAR(200) = '  ADJUSTMENT_DELETE_CODE = ''A'' AND STATUS = ''ACC'' '
		,@AdjRej NVARCHAR(200) = '  ADJUSTMENT_DELETE_CODE = ''A'' AND STATUS = ''REJ'' '
		,@DelTotal NVARCHAR(200) = '  ADJUSTMENT_DELETE_CODE = ''D'' '
		,@DelAcc NVARCHAR(200) = ' ADJUSTMENT_DELETE_CODE = ''D'' AND STATUS = ''ACC'' '
		,@DelRej NVARCHAR(200) = ' ADJUSTMENT_DELETE_CODE = ''D'' AND STATUS = ''REJ'' '
		--Tried to delete PDE with no original PDE in CMS file
		,@Err001 NVARCHAR(200) = ' PDE_ERROR = ''001'''
		--Have a pde, but cannont find a claim
		,@Err003 NVARCHAR(200) = ' PDE_ERROR = ''003'''
		--Tried to adjust PDe with no original PDE in CMS
		,@Err004 NVARCHAR(200) = ' PDE_ERROR = ''004'''
		--Tried to delete PDE which was previously deleted
		,@Err005 NVARCHAR(200) = ' PDE_ERROR = ''005'''
		--PDE was rejected and no associated claim was found
		,@Err006 NVARCHAR(200) = ' PDE_ERROR = ''006'''
		--Test
		,@StartDate DATETIME
		,@EndDate DATETIME

	SET @WhereCondition = 'DRUG_COVERAGE_STATUS_CODE in (''C'',''E'',''O'') '

	IF (
			@pAccuYear IS NULL
			OR @pAccuYear = ''
			)
		SET @pAccuYear = YEAR(GETDATE())

	IF (
			@pProductID IS NULL
			OR @pProductID = ''
			)
		SET @pProductID = ''

	IF @pFieldName IS NULL
		OR @pFieldname = ''
		SET @pFieldName = 'PDE_ACCEPTED'
	SET @WhereCondition = @WhereCondition + ' AND ' + CASE 
			WHEN @pFieldName = 'PDE_TOTAL'
				THEN @PdeTotal
			WHEN @pFieldName = 'PDE_ACCEPTED'
				THEN @PdeAcc
			WHEN @pFieldName = 'PDE_REJECTED'
				THEN @PdeRej
			WHEN @pFieldName = 'ADJ_TOTAL'
				THEN @AdjTotal
			WHEN @pFieldName = 'ADJ_ACCEPTED'
				THEN @AdjAcc
			WHEN @pFieldName = 'ADJ_REJECTED'
				THEN @AdjRej
			WHEN @pFieldName = 'DEL_TOTAL'
				THEN @DelTotal
			WHEN @pFieldName = 'DEL_ACCEPTED'
				THEN @DelAcc
			WHEN @pFieldName = 'DEL_REJECTED'
				THEN @DelRej
			WHEN @pFieldName = 'PDE_ERR_001'
				THEN @Err001
			WHEN @pFieldName = 'PDE_ERR_003'
				THEN @Err003
			WHEN @pFieldName = 'PDE_ERR_004'
				THEN @Err004
			WHEN @pFieldName = 'PDE_ERR_005'
				THEN @Err005
			WHEN @pFieldName = 'PDE_ERR_006'
				THEN @Err006
			ELSE ' '
			END

	/*		SET @WhereCondition = @WhereCondition + ' AND MONTH(BATCH_DATE) = ''' +
							CASE WHEN @pBatchDate LikE 'Jan%' THEN  '1'
							     WHEN @pBatchDate LikE 'Feb%' THEN '2'
								 WHEN @pBatchDate LikE 'Mar%' THEN '3'
								 WHEN @pBatchDate like 'Apr%'THEN '4'
							     WHEN @pBatchDate like 'May%' THEN '5'
								 WHEN @pBatchDate like 'June%' THEN '6'
								 WHEN @pBatchDate like 'July%' THEN '7'
							     WHEN @pBatchDate like 'Aug%' THEN '8'
								 WHEN @pBatchDate like 'Sep%' THEN '9'
								 WHEN @pBatchDate like 'Oct%' THEN '10'
								 WHEN @pBatchDate like 'Nov%' THEN '11'
								 WHEN @pBatchDate like 'Dec%'  THEN '12'
								 ELSE CAST(MONTH(@pBatchDate) AS NVARCHAR)
							END + '''' */
	IF @pBatchDate NOT LIKE '%Summary%'
	BEGIN
		SET @StartDate = @pBatchDate
		SET @EndDate = @StartDate
		SET @WhereCondition = @WhereCondition + ' AND BATCH_DATE BETWEEN ''' + CONVERT(VARCHAR(10), @StartDate, 101) + ''' AND ''' + CONVERT(VARCHAR(10), @EndDate, 101) + ''' '
	END

	IF @pBatchDate LIKE '%ummary%'
	BEGIN
		SET @StartDate = @pAccuMonth + '/1/' + @pAccuYear
		SET @EndDate = DATEADD(m, 1, @StartDate)
		SET @EndDate = DATEADD(d, - 1, @EndDate)
		SET @WhereCondition = @WhereCondition + ' AND BATCH_DATE BETWEEN ''' + CONVERT(VARCHAR(10), @StartDate, 101) + ''' AND ''' + CONVERT(VARCHAR(10), @EndDate, 101) + ''' '
	END

	--Setting offset and data limit
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

	--IF batch date is not the summary, add the day to where the clause
	--if @pBatchDate not like '%Sum%' and @pBatchDate <> '' SET @WhereCondition = @WhereCondition + ' AND DAY(BATCH_DATE) = '''+CAST(DAY(CAST(@pBatchDate AS DATE)) AS NVARCHAR) +''' '
	SET @pSQL = 'SELECT DISTINCT PDPD_ID,CARD_ID AS MEMBER_ID,
	 EXTERNAL_REF AS [PBM_ID],
	-- ELIG.LICS_LEVEL,
	 claims.BSDL_MCTR_TYPE AS DRUG_TIER,' + CASE 
			WHEN @pFieldName IN (
					'PDE_ERR_003'
					,'PDE_ERR_001'
					,'PDE_ERR_004'
					,'PDE_ERR_006'
					)
				THEN 'EXTERNAL_REF' + '+''[PBM]''+'
			ELSE 'CAST(PDED.CLAIM_ID AS NVARCHAR)' + '+''[INTERNAL]''+'
			END + '+''|''+' + 'CONVERT(CHAR(10), BATCH_DATE, 103)' + ' AS CLAM_ID,
	 CASE WHEN NOTES.CLAM_ID IS NULL THEN ''N'' ELSE ''Y'' END AS NOTES,
	 RIGHT(CSPI_ID,1) as LICS_TIER,
	 CASE WHEN BSDL_MCTR_TYPE = 0 THEN CLAM_DRUG_TYPE ELSE BSDL_MCTR_TYPE END as [TIER],

	 PDED.FILL_DT,
	 BATCH_DATE,
	 PDED.PAID_DT,
	 QUANTITY_DISPENSED, 
	 PDED.DAYS_SUPPLY,
	 DRUG_COVERAGE_STATUS_CODE,
	 ADJUSTMENT_DELETE_CODE AS [DELETE],
	 (CASE WHEN (PDED.ADJUSTMENT_DELETE_CODE<>' + '''D''' + ' OR PDED.ADJUSTMENT_DELETE_CODE IS NULL) 
			THEN  (PDED.INGREDIENT_COST_PAID+PDED.DISPENSING_FEE_PAID)  ELSE  (0 - (PDED.INGREDIENT_COST_PAID+DISPENSING_FEE_PAID)) END) AS [COST], 
	 (CASE WHEN (PDED.ADJUSTMENT_DELETE_CODE<>' + '''D''' + ' OR ADJUSTMENT_DELETE_CODE IS NULL) 
			THEN PDED.PATIENT_PAY_AMOUNT ELSE  0 - PDED.PATIENT_PAY_AMOUNT END) AS COPAY, 
	 (CASE WHEN (PDED.ADJUSTMENT_DELETE_CODE<>' + '''D''' + 
		' OR PDED.ADJUSTMENT_DELETE_CODE IS NULL) 
			THEN PDED.CPP ELSE  0 - PDED.CPP END) AS CPP, 
	 (CASE WHEN (PDED.ADJUSTMENT_DELETE_CODE <>' + '''D''' + ' OR PDED.ADJUSTMENT_DELETE_CODE IS NULL) 
			THEN PDED.LICS ELSE  0 - PDED.LICS END) AS LICS, 
	 (CASE WHEN (PDED.ADJUSTMENT_DELETE_CODE<>' + '''D''' + ' OR PDED.ADJUSTMENT_DELETE_CODE IS NULL) 
			THEN PDED.CGDP ELSE  0 - PDED.CGDP END) AS CGDP,'
	SET @pSQL = @pSQL + '(CASE WHEN (PDED.ADJUSTMENT_DELETE_CODE<>' + '''D''' + ' OR PDED.ADJUSTMENT_DELETE_CODE IS NULL) 
			THEN PDED.GDCB ELSE  0 - PDED.GDCB END) AS GDCB,
			(CASE WHEN (PDED.ADJUSTMENT_DELETE_CODE<>' + '''D''' + ' OR PDED.ADJUSTMENT_DELETE_CODE IS NULL) 
			THEN PDED.GDCA ELSE  0 - GDCA END) AS GDCA,
			(CASE WHEN (PDED.ADJUSTMENT_DELETE_CODE<>' + '''D''' + ' OR PDED.ADJUSTMENT_DELETE_CODE IS NULL) 
			THEN PDED.CPP ELSE  0 - PDED.CPP END) AS CPP,
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>' + '''D''' + ' OR ADJUSTMENT_DELETE_CODE IS NULL) 
			THEN PDED.TrOOPA ELSE  0 - PDED.TrOOPA END) AS TrOOPA,
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>' + '''D''' + 
		' OR ADJUSTMENT_DELETE_CODE IS NULL) 
			THEN PDED.TGCDCA ELSE  0 - PDED.TGCDCA END) AS TGCDCA,
            ELIG.PLAN_ID,
            ELIG.PBP

				FROM RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA_RETURN PDED
				LEFT JOIN dbo.RX_CLAIMS claims ON claims.CLAM_ID = PDED.CLAIM_ID AND PDED.PDE_SEQ = claims.PDE_SEQ
				LEFT JOIN dbo.RX_NDC_DRUGS ndc ON ndc.DRUG_NDC_CODE = claims.DRUG_NDC_CODE
				LEFT JOIN MB_MEMBER_ELIGIBILITY ELIG ON claims.MEMBER_CK = ELIG.MEMBER_CK AND claims.CLAM_FILL_DATE BETWEEN EFFECTIVE_DATE AND TERMINATION_DATE 
	            LEFT JOIN (select DISTINCT CLAM_ID  from dbo.PDE_TRACKER_NOTES WHERE ID_TYPE=''' + CASE 
			WHEN @pFieldName IN (
					'PDE_ERR_003'
					,'PDE_ERR_001'
					,'PDE_ERR_004'
					,'PDE_ERR_006'
					)
				THEN 'PBM'
			ELSE 'INTERNAL'
			END + ''') NOTES ON ' + CASE 
			WHEN @pFieldName IN (
					'PDE_ERR_003'
					,'PDE_ERR_001'
					,'PDE_ERR_004'
					,'PDE_ERR_006'
					)
				THEN ' EXTERNAL_REF'
			ELSE ' PDED.CLAIM_ID'
			END + '= NOTES.CLAM_ID
				WHERE 
				' + @WhereCondition + 'ORDER BY BATCH_DATE, PAID_DT,FILL_DT' + @OffsetText

	PRINT @pSQL

	EXEC sp_sqlexec @pSQL
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

PRINT N'Altering [dbo].[PDE_REC_REJ_DETAILS]'
GO

ALTER PROCEDURE [dbo].[PDE_REC_REJ_DETAILS]
	-- Add the parameters for the stored procedure here
	@pACCU_YEAR NVARCHAR(4) = ''
	,@pSearchName NVARCHAR(50) = ''
	,@pSearchType NVARCHAR(10) = ''
	,@pFieldName VARCHAR(8000) = ''
	,@pGroupField NVARCHAR(100) = ''
	,@pGroupValue NVARCHAR(max) = ''
	,@pProductID NVARCHAR(1000) = ''
	,@pMonth NVARCHAR(2) = ''
	,@pFirstErrorOnly VARCHAR(1) = ''
	,@pSQL NVARCHAR(4000) = '' OUTPUT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET QUOTED_IDENTIFIER OFF

	DECLARE @WhereCondition NVARCHAR(max) = ''
		,@type VARCHAR(55) = ''
		,@switch VARCHAR(55) = ''
		,@string NVARCHAR(500) = ''
		,@pos INT
		,@piece NVARCHAR(500)
		,@counter INT
		,@pErrorCodes VARCHAR(max)
		,@pFromStatement NVARCHAR(max) = ''

	--set default values
	IF (
			@pGroupField IS NULL
			OR @pGroupField = ''
			)
		SET @pGroupField = 'ERROR_AGING'

	-- Make Coorection on @pGroupValue @pGroupValue is null, on @pGroupField='ERROR_AGING', use '%'
	IF (
			@pGroupValue IS NULL
			OR @pGroupValue = ''
			)
	BEGIN
		SET @pGroupValue = CASE 
				WHEN @pGroupField = 'ERROR_AGING'
					THEN '%'
				WHEN @pGroupField = 'EDIT_CATEGORY'
					THEN '%'
				WHEN @pGroupField = 'SERVICE_YEAR'
					THEN '%'
				WHEN @pGroupField = 'RESUBMIT'
					THEN '%'
				END
	END

	IF (
			@pFieldName IS NULL
			OR @pFieldName = ''
			)
		SET @pFieldName = 'ERRORS_AMOUNT'

	IF (
			@pACCU_YEAR IS NULL
			OR @pACCU_YEAR = ''
			)
		SET @pACCU_YEAR = YEAR(GETDATE())

	--if you don't have a conditional for serivce year, you will end up with a duplicate YEAR(PAID_DT) = X
	IF @pGroupField <> 'SERVICE_YEAR'
		SET @WhereCondition = ' AND YEAR(PDED.PAID_DT) = ''' + @pACCU_YEAR + ''' '

	IF NOT (
			@pMonth IS NULL
			OR @pMonth = ''
			)
		AND @pGroupField = 'TREND'
		SET @WhereCondition = @WhereCondition + ' AND MONTH(PDED.PAID_DT) = ''' + @pMonth + ''''

	IF NOT (
			@pProductID IS NULL
			OR @pProductID = ''
			)
		SET @WhereCondition = @WhereCondition + ' AND PDPD_ID IN (' + '''' + REPLACE(@pProductID, ',', '''' + ',' + '''') + '''' + ')'
	--parse _ delimited FieldName parameter
	SET @string = @pFieldName
	SET @counter = 1

	IF right(RTRIM(@string), 1) <> '_'
		SELECT @string = @string + '_'

	SELECT @pos = patindex('%[_]%', @string)

	WHILE @pos <> 0
	BEGIN
		SELECT @piece = left(@string, (@pos - 1))

		IF @counter = 1
			SET @type = cast(@piece AS NVARCHAR(512))
		SET @counter = @counter + 1

		SELECT @string = stuff(@string, 1, @pos, '')

		SELECT @pos = patindex('%[_]%', @string)
	END

	--set @pErrorCodes to proper nomenclature
	SET @pErrorCodes = CASE 
			WHEN @type = 'CAT'
				THEN 'Catastrophic'
			WHEN @type = 'COST'
				THEN 'Claims Cost'
			WHEN @type = 'ERRORS'
				THEN 'Claims Errors'
			WHEN @type = 'NDC'
				THEN 'Drug NDC Code'
			WHEN @type = 'LICS'
				THEN 'Claims LICS'
			WHEN @type = 'GAP'
				THEN 'Gap Discount'
			WHEN @type = 'ENROLL'
				THEN 'Member Enrollment'
			END
	--add this to pCode
	SET @WhereCondition = @WhereCondition + ' AND PDER.EDIT_CATEGORY = ''' + @pErrorCodes + ''' AND CLAM_IS_REVERSED = ''N'' AND CLAM_CURRENT_STATUS IN (''P'',''A'',''D'')'

	--Set value for condition
	IF @pGroupValue = '%'
		SET @switch = CASE 
				WHEN @pGroupField = 'ERROR_AGING'
					THEN ' AGING.CODE_TYPE_DESC LIKE '''
				WHEN @pGroupField = 'EDIT_CATEGORY'
					THEN ' EDITES LIKE '''
				WHEN @pGroupField = 'RESUBMIT'
					THEN ' PDED..ERROR_SUBMISSION_NUM LIKE '''
				WHEN @pGroupField = 'SERVICE_YEAR'
					THEN ' YEAR(PDED.FILL_DT) LIKE '''
				END
	ELSE
		SET @switch = CASE 
				WHEN @pGroupField = 'ERROR_AGING'
					THEN ' AGING.CODE_TYPE_DESC = '''
				WHEN @pGroupField = 'EDIT_CATEGORY'
					THEN ' EDITES LIKE '''
				WHEN @pGroupField = 'RESUBMIT'
					THEN ' PDED.ERROR_SUBMISSION_NUM ='''
				WHEN @pGroupField = 'SERVICE_YEAR'
					THEN ' YEAR(PDED.FILL_DT) = '''
				END

	PRINT @pGroupField
	PRINT @pGroupValue
	PRINT @WhereCondition

	--parse | delimited GroupValue parameter, not required for Trend graph
	IF @pGroupField <> 'TREND'
	BEGIN
		SET @counter = 1
		SET @WhereCondition = @WhereCondition + ' AND ('
		SET @string = @pGroupValue

		IF right(RTRIM(@string), 1) <> '|'
			SELECT @string = @string + '|'

		SELECT @pos = patindex('%[|]%', @string)

		WHILE @pos <> 0
		BEGIN
			SELECT @piece = left(@string, (@pos - 1))

			--build pCode String
			IF @counter <> 1
				SET @WhereCondition = @WhereCondition + 'OR '

			--only select numbers from resubmit, I.E. Change "2 resubmission" to "2"
			IF @pGroupField = 'RESUBMIT'
				SET @piece = SUBSTRING(@piece, 1, CHARINDEX(' ', @piece) - 1)

			IF @pGroupField = 'EDIT_CATEGORY'
				SET @WhereCondition = @WhereCondition + @switch + @piece + '%'' '
			ELSE
				SET @WhereCondition = @WhereCondition + @switch + @piece + ''' '

			SET @counter = @counter + 1

			SELECT @string = stuff(@string, 1, @pos, '')

			SELECT @pos = patindex('%[|]%', @string)
		END

		SET @WhereCondition = @WhereCondition + ' )'
	END

	PRINT @WhereCondition

	--Change to first error code only or all Error codes.  @pFirstErrorOnly Value of Y sets to first error code
	SET @pFromStatement = CASE 
			WHEN upper(@pFirstErrorOnly) = 'Y'
				THEN 'FROM dbo.RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA PDED
		JOIN RX_CLAIMS claims ON PDED.CLAIM_ID = claims.CLAM_ID AND PDED.PDE_SEQ = claims.PDE_SEQ
		JOIN dbo.RX_CMS_PDED_DETAIL_ERROR_CODE PDEDD ON PDED.CLAIM_ID=PDEDD.CLAIM_ID AND PDED.ERROR_SUBMISSION_NUM = PDEDD.ERROR_SUBMISSION_NUM AND SUBSTRING(PDED.ERROR_CODE,1,3) = PDEDD.ERROR_CODE
		JOIN dbo.PDE_REJECT_CODE PDER on PDEDD.ERROR_CODE = PDER.ERROR_CODE'
			ELSE 'from dbo.RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA PDED 
		INNER JOIN dbo.RX_CLAIMS claims ON claims.CLAM_ID = PDED.CLAIM_ID AND PDED.PDE_SEQ = claims.PDE_SEQ
		INNER JOIN dbo.RX_CMS_PDED_DETAIL_ERROR_CODE PDEDD ON PDED.CLAIM_ID=PDEDD.CLAIM_ID AND PDED.ERROR_SUBMISSION_NUM = PDEDD.ERROR_SUBMISSION_NUM
		INNER JOIN dbo.PDE_REJECT_CODE PDER on PDEDD.ERROR_CODE = PDER.ERROR_CODE'
			END

	IF (
			@pProductID IS NULL
			OR @pProductID = ''
			)
		SET @pProductID = '%%'
	SET @pSQL = '
	SELECT 
		PDPD_ID
		,RX_MEME_ID AS MEMBER_ID
		,CLAM_CHECK_REFERENCE_NUMBER AS [PBM_ID]
		,PDER.EDITES AS ERROR_DESC
		,ELIG.LICS_LEVEL
		, RIGHT(CSPI_ID,1) as [LICS_TIER]
		 ,CASE WHEN BSDL_MCTR_TYPE = 0 THEN CLAM_DRUG_TYPE ELSE BSDL_MCTR_TYPE END as [TIER]
		 ,CASE WHEN NOTES.CLAM_ID IS NULL THEN ''N'' ELSE ''Y'' END AS NOTES
		,PDER.ERROR_CODE AS ERROR_CODE
		,claims.BSDL_MCTR_TYPE AS DRUG_TIER
		,datediff(day,PDED.BATCH_DATE, getdate()) AS ERROR_AGING
		,claims.CLAM_ID
		,CAST(FILL_DT AS DATE) AS FILL_DT
		,CAST(CLAM_ORIGINAL_ENTRY_DATE AS DATE) AS PAID_DT
		,QUANTITY_DISPENSED
		,DAYS_SUPPLY
		,DRUG_COVERAGE_STATUS_CODE
		,ADJUSTMENT_DELETE_CODE AS [DELETE]
		,(CASE WHEN (ADJUSTMENT_DELETE_CODE<>' + '''D''' + ' OR ADJUSTMENT_DELETE_CODE IS NULL) 
			THEN  (INGREDIENT_COST_PAID+DISPENSING_FEE_PAID)  ELSE  (0 - (INGREDIENT_COST_PAID+DISPENSING_FEE_PAID)) END) AS [COST]
		,(CASE WHEN (ADJUSTMENT_DELETE_CODE<>' + '''D''' + 
		' OR ADJUSTMENT_DELETE_CODE IS NULL) 
			THEN PATIENT_PAY_AMOUNT ELSE  0 - PATIENT_PAY_AMOUNT END) AS COPAY
		,(CASE WHEN (ADJUSTMENT_DELETE_CODE<>' + '''D''' + ' OR ADJUSTMENT_DELETE_CODE IS NULL) 
			THEN CPP ELSE  0 - CPP END) AS CPP
		,(CASE WHEN (ADJUSTMENT_DELETE_CODE <>' + '''D''' + ' OR ADJUSTMENT_DELETE_CODE IS NULL) 
			THEN LICS ELSE  0 - LICS END) AS LICS
		,(CASE WHEN (ADJUSTMENT_DELETE_CODE<>' + '''D''' + ' OR ADJUSTMENT_DELETE_CODE IS NULL) 
			THEN CGDP ELSE  0 - CGDP END) AS CGDP'
	SET @pSQL = @pSQL + ',(CASE WHEN (ADJUSTMENT_DELETE_CODE<>' + '''D''' + ' OR ADJUSTMENT_DELETE_CODE IS NULL) 
				THEN GDCB ELSE  0 - GDCB END) AS GDCB
			,(CASE WHEN (ADJUSTMENT_DELETE_CODE<>' + '''D''' + ' OR ADJUSTMENT_DELETE_CODE IS NULL) 
				THEN GDCA ELSE  0 - GDCA END) AS GDCA
			,(CASE WHEN (ADJUSTMENT_DELETE_CODE<>' + '''D''' + ' OR ADJUSTMENT_DELETE_CODE IS NULL) 
				THEN CPP ELSE  0 - CPP END) AS CPP
			,(CASE WHEN (ADJUSTMENT_DELETE_CODE<>' + '''D''' + ' OR ADJUSTMENT_DELETE_CODE IS NULL) 
				THEN TrOOPA ELSE  0 - TrOOPA END) AS TrOOPA
			,(CASE WHEN (ADJUSTMENT_DELETE_CODE<>' + '''D''' + ' OR ADJUSTMENT_DELETE_CODE IS NULL) 
				THEN PDED.TGCDCA ELSE  0 - PDED.TGCDCA END) AS TGCDCA
			,PDEDD.ERROR_CODE
			,rtrim(rtrim(PDEDD.ERROR_CODE) + '' - '' + EDITES) as EDITES
            ,PDED.PLAN_ID
            ,PDED.PBP
	' + @pFromStatement + 
		'
			left JOIN dbo.RX_NDC_DRUGS ndc ON ndc.DRUG_NDC_CODE = claims.DRUG_NDC_CODE
			LEFT JOIN (select DISTINCT CLAM_ID  from dbo.PDE_REC_NOTES_REJ) NOTES ON claims.CLAM_ID = NOTES.CLAM_ID
			JOIN SUP_SUPPORT_CODE AGING ON CODE_TYPE=''DAY_RANGE'' AND DATEDIFF(DAY,BATCH_DATE,GETDATE()) BETWEEN CAST(CODE AS INT) AND CAST(CODE_DESC AS INT)
			LEFT JOIN MB_MEMBER_ELIGIBILITY ELIG ON claims.MEMBER_CK = ELIG.MEMBER_CK AND claims.CLAM_FILL_DATE BETWEEN EFFECTIVE_DATE AND TERMINATION_DATE 
	WHERE PDED.STATUS=''REJ''  AND DRUG_COVERAGE_STATUS_CODE IN (''C'',''E'',''O'')  ' + @WhereCondition + ' ORDER BY CLAM_ORIGINAL_ENTRY_DATE'

	PRINT @pSQL

	EXEC sp_sqlexec @pSQL
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

PRINT N'Altering [dbo].[PDE_P2P_REC_DETAILS]'
GO

ALTER PROCEDURE [dbo].[PDE_P2P_REC_DETAILS] (
	@pAccuYear VARCHAR(4) = ''
	,@pFieldName VARCHAR(50) = ''
	,@pP2PStatus VARCHAR(10) = ''
	,@pMonth VARCHAR(2) = ''
	,@pMemberID VARCHAR(25) = ''
	,@pClaimID VARCHAR(25) = ''
	,@pProductID NVARCHAR(10) = NULL
	,@pDataLimit NVARCHAR(10) = ''
	,@pOffSet NVARCHAR(10) = ''
	,@pSQL NVARCHAR(max) = '' OUTPUT
	)
AS
BEGIN
	DECLARE @pWhereCondition VARCHAR(4000) = ''
		,@OffsetText NVARCHAR(1000) = ''

	-- set default values
	IF @pAccuYear IS NULL
		OR @pAccuYear = ''
		SET @pAccuYear = YEAR(GETDATE())

	IF @pP2PStatus IS NULL
		OR @pP2PStatus = ''
		SET @pP2PStatus = 'Received'

	IF @pFieldName IS NULL
		OR @pFieldName = ''
		SET @pFieldName = 'PROCESSED_AMOUNT'
	-- build where condition
	SET @pWhereCondition = CASE 
			WHEN @pP2PStatus = 'Received'
				THEN '  a.TRANSACTION_CODE = ''41'' '
			WHEN @pP2PStatus = 'Payable'
				THEN ' a.TRANSACTION_CODE = ''43'' '
			END
	SET @pWhereCondition = @pWhereCondition + ' AND YEAR(a.Date) = ''' + @pAccuYear + ''' '

	IF @pMonth <> ''
		SET @pWhereCondition = @pWhereCondition + ' AND MONTH(a.Date) = ''' + @pMonth + ''' '
	SET @pWhereCondition = @pWhereCondition + CASE 
			WHEN @pFieldName = 'PROCESSED_AMOUNT'
				THEN ' AND NOT (CHECK_DATE IS NULL AND CHECK_NO IS NULL)  '
			WHEN @pFieldName = 'PROCESSED_COUNT'
				THEN '  AND NOT (CHECK_DATE IS NULL AND CHECK_NO IS NULL)  '
			WHEN @pFieldName = 'REQUIRED_AMOUNT'
				THEN '  '
			WHEN @pFieldName = 'REQUIRED_COUNT'
				THEN '  '
			WHEN @pFieldName = 'OUTSTANDING_AMOUNT'
				THEN ' AND CHECK_DATE IS NULL AND CHECK_NO IS NULL '
			WHEN @pFieldName = 'OUTSTANDING_COUNT'
				THEN ' AND CHECK_DATE IS NULL AND CHECK_NO IS NULL '
			WHEN @pFieldName = 'ERRORS_AMOUNT'
				THEN ' AND NOT (CHECK_DATE IS NULL AND CHECK_NO IS NULL) AND CHECK_AMOUNT <> CURRENT_MONTH_P2P_AMT_DUE_FROM_TO_ALL_SUBMITTING_CONTRACTS '
			WHEN @pFieldName = 'ERRORS_COUNT'
				THEN ' AND NOT (CHECK_DATE IS NULL AND CHECK_NO IS NULL) AND CHECK_AMOUNT <> CURRENT_MONTH_P2P_AMT_DUE_FROM_TO_ALL_SUBMITTING_CONTRACTS '
			END

	--etting Offset			
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

	-- build select statement
	SET @pSQL = 'SELECT 
	CONTRACT_NO AS CONTRACT_ID,
	a.COVERAGE,
	a.Date AS DATE,
	PLAN_ID,
	TRANSACTION_CODE,
	pc.CONTRACT_NAME AS HEALTH_PLAN,
	[CURRENT_MONTH_P2P_AMT_DUE_FROM_TO_ALL_SUBMITTING_CONTRACTS] as AMOUNT_DUE,
	BENEFICIARY_COUNT,
	FIR_COUNT,
	CHECK_DATE,
	CHECK_NO,
	CHECK_AMOUNT,
	UPDATE_PERSON,
	UPDATE_DATE,

	cast([TRANSACTION_CODE] as nvarchar)+''|''+cast([CONTRACT_ID] as nvarchar) + ''|''+ cast(a.COVERAGE as nvarchar)++ ''|''+ cast(ISNULL(PLAN_ID,'''') as nvarchar)  AS [KEY]
	FROM [dbo].[PDE_P2P_AMOUNT] a
	LEFT JOIN (SELECT distinct CONTRACT_ID, CONTRACT_NAME FROM dbo.SUP_P2P_PLAN_NAME ) pc
	on a.CONTRACT_NO = pc.CONTRACT_ID
	WHERE ' + @pWhereCondition + 'Order by pc.CONTRACT_NAME,[CURRENT_MONTH_P2P_AMT_DUE_FROM_TO_ALL_SUBMITTING_CONTRACTS]' + @OffsetText

	PRINT @pSQL

	EXEC sp_executesql @pSQL
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

PRINT N'Altering [dbo].[PDE_REC_DETAILS]'
GO

-- PDE_REC_DETAILS @pACCU_YEAR= '2014', @pMONTH = '2'
--Modify by BC, ACCU_YEAR and Month should based on PAID_DT, not the Fill Date.
ALTER PROCEDURE [dbo].[PDE_REC_DETAILS] (
	@pACCU_YEAR VARCHAR(4) = ''
	,@pFieldName VARCHAR(50) = ''
	,@pPDE_STATUS VARCHAR(1000) = ''
	,@pMONTH VARCHAR(2) = ''
	,@pMemberID VARCHAR(25) = ''
	,@pClaimID VARCHAR(25) = ''
	,@pProductID NVARCHAR(1000) = NULL
	,@pDataLimit NVARCHAR(10) = ''
	,@pOffSet NVARCHAR(10) = ''
	,@pSQL NVARCHAR(max) = '' OUTPUT
	)
AS
BEGIN
	-- Modify by BC, ACCU_YEAR and Month should based on PAID_DT, not the Fill Date.
	DECLARE @WhereCondition VARCHAR(1500) = ''
		,@type VARCHAR(55) = ''
		,@switch VARCHAR(55) = ''
		,@string NVARCHAR(500) = ''
		,@pos INT
		,@piece NVARCHAR(500)
		,@counter INT
		,@condition VARCHAR(100)
		,@Date NVARCHAR(50) = 'PAID_DT'
		,@OffsetText NVARCHAR(1000) = ''

	IF @pFieldName IS NULL
		OR @pFieldName = ''
		SET @string = 'COVERED_AMOUNT'
	ELSE
		SET @string = @pFieldName

	IF @pACCU_YEAR = ''
		OR @pACCU_YEAR IS NULL
		SET @pACCU_YEAR = YEAR(getdate())

	IF (@pPDE_STATUS = 'ALL')
		SET @WhereCondition = ' '

	IF @pPDE_STATUS = 'ACC'
		SET @WhereCondition = '( @pPDE_STAT = ISNULL(STATUS,'''') OR STATUS = ''INF'' OR STATUS = ''CLN'' ) AND '

	IF @pPDE_STATUS = 'INF'
		SET @WhereCondition = '( @pPDE_STAT = ISNULL(STATUS,'''') OR STATUS = ''ACC'' OR STATUS = ''CLN'') AND '

	IF @pPDE_STATUS = NULL
		OR @pPDE_STATUS = 'REJ'
		OR @pPDE_STATUS = ''
		SET @WhereCondition = ' ISNULL(@pPDE_STAT, '''') = ISNULL(STATUS,'''')  AND'
	SET @WhereCondition = @WhereCondition + '  CLAM_CURRENT_STATUS IN (''P'',''A'',''D'') AND CLAM_IS_REVERSED = ''N'' AND DRUG_COVERAGE_STATUS_CODE IN (''C'',''E'',''O'')  AND '

	IF NOT (
			@pMONTH IS NULL
			OR @pMONTH = ''
			)
		SET @WhereCondition = @WhereCondition + ' MONTH(' + @Date + ') = ''' + @pMONTH + ''' AND '

	IF NOT (
			@pProductID IS NULL
			OR @pProductID = ''
			)
		SET @WhereCondition = @WhereCondition + ' AND PDPD_ID IN (' + '''' + REPLACE(@pProductID, ',', '''' + ',' + '''') + '''' + ')'
	SET @counter = 1

	IF right(RTRIM(@string), 1) <> '_'
		SELECT @string = @string + '_'

	SELECT @pos = patindex('%[_]%', @string)

	WHILE @pos <> 0
	BEGIN
		SELECT @piece = left(@string, (@pos - 1))

		IF @counter = 1
			SET @type = cast(@piece AS NVARCHAR(512))

		IF @counter = 2
			SET @switch = cast(@piece AS NVARCHAR(512))
		SET @counter = @counter + 1

		SELECT @string = stuff(@string, 1, @pos, '')

		SELECT @pos = patindex('%[_]%', @string)
	END

	IF @type = 'OTC'
		SET @condition = ' DRUG_COVERAGE_STATUS_CODE = ''O'''

	IF @type = 'ENHANCED'
		SET @condition = 'DRUG_COVERAGE_STATUS_CODE = ''E'''

	IF @type = 'COVERED'
		SET @condition = 'DRUG_COVERAGE_STATUS_CODE = ''C'''

	IF (
			@type <> 'OTC'
			AND @type <> 'ENHANCED'
			AND @type <> 'COVERED'
			)
		SET @condition = @type + ' <> 0 '

	IF (@pMemberID <> '')
		SET @condition = @condition + ' AND RX_MEME_ID = ''' + CAST(@pMemberID AS NVARCHAR(25)) + ''''

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

	SET @pSQL = 'SELECT 
	 RX_MEME_ID AS MEMBER_ID,
	 CLAM_CHECK_REFERENCE_NUMBER AS [PBM_ID], 
	 B.CLAM_ID,
	 RIGHT(CSPI_ID,1) as [LICS_TIER],
	 CASE WHEN NOTES.CLAM_ID IS NULL THEN ''N'' ELSE ''Y'' END AS NOTES,
	 CASE WHEN BSDL_MCTR_TYPE = 0 THEN CLAM_DRUG_TYPE ELSE BSDL_MCTR_TYPE END as [TIER],
	 FILL_DT,
	 CLAM_ORIGINAL_ENTRY_DATE  AS PAID_DT,
	 QUANTITY_DISPENSED, 
	 DAYS_SUPPLY,
	 DRUG_COVERAGE_STATUS_CODE,
	 ADJUSTMENT_DELETE_CODE AS [DELETE],

	 (CASE WHEN (ADJUSTMENT_DELETE_CODE<>' + '''D''' + ' OR ADJUSTMENT_DELETE_CODE IS NULL) 
			THEN  (INGREDIENT_COST_PAID+DISPENSING_FEE_PAID)  ELSE  (0 - (INGREDIENT_COST_PAID+DISPENSING_FEE_PAID)) END) AS [COST], 
	 (CASE WHEN (ADJUSTMENT_DELETE_CODE<>' + '''D''' + ' OR ADJUSTMENT_DELETE_CODE IS NULL) 
			THEN PATIENT_PAY_AMOUNT ELSE  0 - PATIENT_PAY_AMOUNT END) AS COPAY, 
	 (CASE WHEN (ADJUSTMENT_DELETE_CODE<>' + '''D''' + ' OR ADJUSTMENT_DELETE_CODE IS NULL) 
			THEN CPP ELSE  0 - CPP END) AS CPP, 
	 (CASE WHEN (ADJUSTMENT_DELETE_CODE <>' + '''D''' + 
		' OR ADJUSTMENT_DELETE_CODE IS NULL) 
			THEN LICS ELSE  0 - LICS END) AS LICS, 
	 (CASE WHEN (ADJUSTMENT_DELETE_CODE<>' + '''D''' + ' OR ADJUSTMENT_DELETE_CODE IS NULL) 
			THEN CGDP ELSE  0 - CGDP END) AS CGDP,'
	SET @pSQL = @pSQL + '(CASE WHEN (ADJUSTMENT_DELETE_CODE<>' + '''D''' + ' OR ADJUSTMENT_DELETE_CODE IS NULL) 
			THEN GDCB ELSE  0 - GDCB END) AS GDCB,
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>' + '''D''' + ' OR ADJUSTMENT_DELETE_CODE IS NULL) 
			THEN GDCA ELSE  0 - GDCA END) AS GDCA,
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>' + '''D''' + ' OR ADJUSTMENT_DELETE_CODE IS NULL) 
			THEN CPP ELSE  0 - CPP END) AS CPP,
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>' + '''D''' + ' OR ADJUSTMENT_DELETE_CODE IS NULL) 
			THEN TrOOPA ELSE  0 - TrOOPA END) AS TrOOPA,
			(CASE WHEN (ADJUSTMENT_DELETE_CODE<>' + '''D''' + ' OR ADJUSTMENT_DELETE_CODE IS NULL) 
			THEN A.TGCDCA ELSE  0 - A.TGCDCA END) AS TGCDCA,
            A.PLAN_ID,
            A.PBP	
			   FROM dbo.RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA A
				JOIN RX_CLAIMS B ON A.CLAIM_ID = B.CLAM_ID AND A.PDE_SEQ = B.PDE_SEQ
				LEFT JOIN (select DISTINCT R.CLAM_ID  from dbo.PDE_REC_NOTES_REJ R) NOTES ON NOTES.CLAM_ID = B.CLAM_ID
				  WHERE ' + @WhereCondition + 
		' YEAR(PAID_DT) = ''' + @pACCU_YEAR + ''' AND ' + @condition + ' 
				  ORDER BY B.RX_MEME_ID, B.CLAM_ORIGINAL_ENTRY_DATE
				  ' + @OffsetText

	PRINT @pSQL

	EXEC sp_executesql @pSQL
		,N'@pPDE_STAT nvarchar(75)'
		,@pPDE_STAT = @pPDE_STATUS
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

PRINT N'Creating [dbo].[PDE_FIR_POP_CLAIM_LIST_TITLE]'
GO

CREATE PROCEDURE [dbo].[PDE_FIR_POP_CLAIM_LIST_TITLE] (@pSQL NVARCHAR(max) = '' OUTPUT)
AS
BEGIN
	SET @pSQL = 'SELECT ''Member Claims List'' AS TITLE, NULL AS COLOR_PICKER'

	PRINT @pSQL

	EXEC sp_executesql @pSQL
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

PRINT N'Creating [dbo].[PDE_REC_CLAIM_DETAILS_NOTES]'
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- Build by PJ
-- =============================================
CREATE PROCEDURE [dbo].[PDE_REC_CLAIM_DETAILS_NOTES] @pKey NVARCHAR(30) = ''
	,@pStatus NVARCHAR(10) = ''
	,@pAccuYear NVARCHAR(4) = ''
	,@pFirstErrorOnly VARCHAR(1) = ''
AS
BEGIN
	DECLARE @WhereCondition NVARCHAR(500)
		,@SQL NVARCHAR(max) = ''
		,@MemberID NVARCHAR(50) = ''
		,@ClaimID NVARCHAR(25) = ''
		,@StartDate DATETIME
		,@EndDate DATETIME
		,@FromStatement NVARCHAR(max) = ''
		,@FindDistinctClaims NVARCHAR(max) = ''

	IF @pStatus = 'ACC'
		SET @WhereCondition = '  WHERE ( @pPDE_STAT = ISNULL(A.STATUS,'''') OR A.STATUS = ''INF'' OR A.STATUS = ''CLN'') and CLAM_CURRENT_STATUS IN (''P'',''A'',''D'') '

	IF @pStatus = 'INF'
		SET @WhereCondition = '  WHERE ( @pPDE_STAT = ISNULL(A.STATUS,'''') OR A.STATUS = ''ACC'' OR A.STATUS = ''CLN'') AND CLAM_CURRENT_STATUS IN (''P'',''A'',''D'')'

	IF @pStatus IS NULL
		OR @pStatus = 'REJ'
		OR @pStatus = ''
		SET @WhereCondition = ' WHERE ISNULL(@pPDE_STAT, '''') = ISNULL(A.STATUS,'''') '

	IF @pAccuYear IS NULL
		OR @pAccuYear = ''
		SET @pAccuYear = '2015'
	SET @ClaimID = @pKey

	--Supply default parameter value to allow proc to run and return results with no parameters specified
	IF @ClaimID IS NULL
		OR @ClaimID = ''
		SET @ClaimID = N'1918630'

	IF @pStatus <> 'REJ'
		SET @FromStatement = 'dbo.RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA A
				JOIN RX_CLAIMS B ON A.CLAIM_ID = B.CLAM_ID AND A.PDE_SEQ = B.PDE_SEQ'
	ELSE
	BEGIN
		SET @FromStatement = CASE 
				WHEN upper(@pFirstErrorOnly) = 'Y'
					THEN ' dbo.RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA A
			JOIN RX_CLAIMS B ON A.CLAIM_ID = B.CLAM_ID --AND A.PDE_SEQ = B.PDE_SEQ
			LEFT join RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA_GAP C ON A.CLAIM_ID = C.CLAM_ID AND A.PDE_SEQ = C.PDE_SEQ
			JOIN MB_ENROLLEE_INFO D ON B.RX_MEME_ID = D.MEMBER_ID
			LEFT JOIN RX_NDC_DRUGS E ON B.DRUG_NDC_CODE = E.DRUG_NDC_CODE
			JOIN dbo.RX_CMS_PDED_DETAIL_ERROR_CODE PDEDD ON A.CLAIM_ID=PDEDD.CLAIM_ID AND A.ERROR_SUBMISSION_NUM = PDEDD.ERROR_SUBMISSION_NUM AND SUBSTRING(A.ERROR_CODE,1,3) = PDEDD.ERROR_CODE
			JOIN dbo.PDE_REJECT_CODE PDER on PDEDD.ERROR_CODE = PDER.ERROR_CODE'
				ELSE ' dbo.RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA A
			INNER JOIN RX_CLAIMS B ON A.CLAIM_ID = B.CLAM_ID --AND A.PDE_SEQ = B.PDE_SEQ 
			LEFT join RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA_GAP C ON A.CLAIM_ID = C.CLAM_ID AND A.PDE_SEQ = C.PDE_SEQ
			JOIN MB_ENROLLEE_INFO D ON B.RX_MEME_ID = D.MEMBER_ID
			LEFT JOIN RX_NDC_DRUGS E ON B.DRUG_NDC_CODE = E.DRUG_NDC_CODE
			INNER JOIN dbo.RX_CMS_PDED_DETAIL_ERROR_CODE PDEDD ON A.CLAIM_ID=PDEDD.CLAIM_ID
			INNER JOIN dbo.PDE_REJECT_CODE PDER ON PDEDD.ERROR_CODE = PDER.ERROR_CODE AND A.ERROR_SUBMISSION_NUM = PDEDD.ERROR_SUBMISSION_NUM'
				END
	END

	SET @WhereCondition = @WhereCondition + ' AND B.CLAM_ID = ''' + @ClaimID + ''' AND  DRUG_COVERAGE_STATUS_CODE IN (''C'',''E'',''O'')  '

	IF @pStatus = 'REJ'
		SET @WhereCondition = @WhereCondition + ' AND CLAM_CURRENT_STATUS IN (''P'',''A'',''D'') AND CLAM_IS_REVERSED = ''N'' '
	SET @StartDate = @pAccuYear + '-01-01'
	SET @EndDate = @pAccuYear + '-12-31'
	SET @WhereCondition = @WhereCondition + ' AND PAID_DT BETWEEN ''' + CONVERT(VARCHAR(10), @StartDate, 101) + ''' AND ''' + CONVERT(VARCHAR(10), @EndDate, 101) + ''' '

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
	SET @SQL = 'SELECT CLAM_ID,UPDATE_STATUS_DATE,
  ''=#''+cast(UPDATE_STATUS_DATE AS NVARCHAR)+''#=''+''=#by ''+cast(UPDATE_STATUS_PERSON AS NVARCHAR)+''#=''+''=#''+CAST(NOTES AS NVARCHAR(MAX)) +''#='' AS [KEY] 
 	FROM dbo.PDE_REC_NOTES_REJ
	WHERE CLAM_ID = ''' + @ClaimID + ''' 
	ORDER BY UPDATE_STATUS_DATE'

	PRINT @SQL

	INSERT INTO #tempNotes
	EXEC sp_executesql @SQL

	--second formated table
	CREATE TABLE #formatedTemp (
		CLAIM_ID BIGINT
		,[KEY] NVARCHAR(max)
		)

	--query puts notes in a single string from the previous table
	SET @SQL = ' Select distinct ST2.CLAIM_ID,
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
	EXEC sp_executesql @SQL

	PRINT @SQL

	-- Create a temporary table with the distinct claims to join on the for the member.
	SET @FindDistinctClaims = 'SELECT CLAM_ID,[ORDER] FROM 
							( SELECT B.CLAM_ID
							,ROW_NUMBER() OVER(PARTITION BY B.CLAM_ID ORDER BY CLAM_ORIGINAL_ENTRY_DATE) AS RN
							,ROW_NUMBER() OVER(ORDER BY CLAM_ORIGINAL_ENTRY_DATE) AS [ORDER]
							,CLAM_ORIGINAL_ENTRY_DATE
					 FROM ' + @FromStatement + '
					' + @WhereCondition + ' ) 
					 Claims WHERE RN = 1
					 ORDER BY CLAM_ORIGINAL_ENTRY_DATE
					 '

	CREATE TABLE #DistinctClaims (
		CLAM_ID BIGINT
		,[ORDER] INT
		)

	INSERT INTO #DistinctClaims
	EXEC sp_executesql @FindDistinctClaims
		,N'@pPDE_STAT nvarchar(75)'
		,@pPDE_STAT = @pStatus

	SET @SQL = N'SELECT  Claims.CLAM_ID,
[KEY] AS NOTES 
FROM
#DistinctClaims Claims
LEFT JOIN #formatedTemp NOTES ON Claims.CLAM_ID = NOTES.CLAIM_ID
order by [ORDER]'

	PRINT cast(@SQL AS TEXT)

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

PRINT N'Creating [dbo].[PDE_REC_CLAIM_DETAILS_ACC_TITLE]'
GO

CREATE PROCEDURE [dbo].[PDE_REC_CLAIM_DETAILS_ACC_TITLE] (
	@pKey VARCHAR(50) = ''
	,@pPdeStatus VARCHAR(10) = ''
	,@pProductID NVARCHAR(10) = NULL
	,@pMonth NVARCHAR(2) = ''
	,@pFirstErrorOnly VARCHAR(1) = ''
	,@pSQL NVARCHAR(max) = '' OUTPUT
	)
AS
BEGIN
	DECLARE @pWhereCondition NVARCHAR(max) = ''
		,@pFromStatement NVARCHAR(max) = ''
		,@JoinParameter NVARCHAR(1000) = ''
		,@PbmID NVARCHAR(50) = ''
		,@ClaimID NVARCHAR(50) = ''

	SET @ClaimID = @pKey

	--SET DEFAULT PARAMETERS
	IF @ClaimID IS NULL
		OR @ClaimID = ''
		SET @ClaimID = '1826937'
	SET @pWhereCondition = 'A.CLAIM_ID = ''' + @ClaimID + ''' AND DRUG_COVERAGE_STATUS_CODE IN (''C'',''E'',''O'')'
	--Set columns for select statement
	SET @pSQL = 'SELECT		
		 ''=# Claim ID: '' +CLAM_CHECK_REFERENCE_NUMBER +''#==#''+E.DRUG_NAME+''#='' AS TITLE
		 , NULL AS COLOR_PICKER
			--CLAM_CHECK_REFERENCE_NUMBER AS [PBM_ID], 		  
		--	E.DRUG_NAME'
	SET @pSQL = @pSQL + '
				FROM dbo.RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA A
			JOIN RX_CLAIMS B ON A.CLAIM_ID = B.CLAM_ID AND A.PDE_SEQ = B.PDE_SEQ
			LEFT JOIN RX_CMS_PDED_PRESCRIPTION_DRUG_EVENT_DATA_GAP C ON A.CLAIM_ID = C.CLAM_ID AND A.PDE_SEQ = C.PDE_SEQ
			JOIN MB_ENROLLEE_INFO D ON B.RX_MEME_ID = D.MEMBER_ID
			LEFT JOIN RX_NDC_DRUGS E ON B.DRUG_NDC_CODE = E.DRUG_NDC_CODE
				WHERE ' + @pWhereCondition + '
				order by CLAM_ORIGINAL_ENTRY_DATE'

	PRINT @pSQL

	EXEC sp_executesql @pSQL
		,N'@pDyanmicStatusVariable nvarchar(75)'
		,@pDyanmicStatusVariable = @pPdeStatus
END
GO

