create or replace PROCEDURE USP_NBMB_AUTO_DIALER_ADD_IN
(
    p_DD_PARTITION_DATE      DATE,
    p_ND_KEY_HASH            NUMBER,
    p_RECORD_SOURCE_ID       NUMBER,
    p_SD_TIEBREAKER          VARCHAR2,
    p_ACTION_LEVEL_ID        NUMBER,
    p_ACTION_LEVEL_KEY       VARCHAR2,
    p_PORTFOLIO_ID           NUMBER,
    p_DD_DATE                TIMESTAMP,
    p_ACTION_TYPE_ID         NUMBER,
    p_EMM_ENABLED            NUMBER,
    p_SHOWSTATE              NUMBER,
    p_AUTO_UPDATES_ALLOWED   NUMBER,
    p_RULE_ID                NUMBER,
    p_SM_BIN                 VARCHAR2,
    p_SM_FIID                VARCHAR2,
    p_ALERT_DATE             TIMESTAMP,
    p_LTEAMID                NUMBER,
    p_LREVID                 NUMBER,
    p_SHOST_VALUE            NVARCHAR2,
    p_LOCALE_ID              VARCHAR2,
    p_ACTION_DESCRIPTION     NVARCHAR2,
    p_ACTION_DATETIME        TIMESTAMP,
    p_ACTION_ORDER           NUMBER,
    p_AUTO_ADDIN_TYPE        NUMBER 
)
    
AS
     V_AUTO_DIALER_FLAG             NUMBER(1);
     V_CNT_RULE_IDS                 NUMBER(10,0);   
     V_RULE_NAME                    NVARCHAR2(255);
     V_LACTION_TYPE_ID              NUMBER(10,0);
     V_SACT_ACTION                  NUMBER(10,0);
     V_ACT_SACTNOTES2               NVARCHAR2(255);
     V_OTHER_ACTION_TYPE_ID         NUMBER(10,0);
     V_CHECK_RULE_ID                NUMBER(10,0);
     V_MESSAGE                      VARCHAR2(4000);
     V_CAMPAIGN_ID                  NVARCHAR2(5);
     V_MAX_RULEID                   NUMBER(10,0);
     V_INS_CAMPAIGN_ID              NVARCHAR2(5);   
     V_DD_APDATE                    TIMESTAMP;
     V_TDDATEKEY                    VARCHAR2(21);
     
     ----ADDED TO INSERT AUTO ACTION(0,3,5) FIALED RECORD INTO ACT TABLE 
     V_AUTOACT_LACTID               NUMBER(10,0);
     V_AUTOACT_STEXT                NUMBER(10,0);
     V_AUTOACT_TYPE                 NUMBER(10,0);
     
     --TO USE A MESSAGE_ID TO DELETE UNWANTED AUTO ACTIONS  
     V_LPRIOMESSAGE_ID              VARCHAR2(4000);
     V_SQL_QUERY                    VARCHAR2(4000);
     V_IF_COUNT                     INTEGER;
     V_IF_RULE_CRITERIA             INTEGER;
     V_IF_DYNAMIC_CSM_ENABLED       INTEGER;
     V_IF_RULECRITERIA_FAILED       INTEGER;
     
     --To filter variable value
     V_VALID_RULE_ID                VARCHAR2(200);
     V_VALID_DIALER_ACTION_TYPE_ID  VARCHAR2(200);
     V_VALID_SDTIEBREAKER           VARCHAR2(200);
     V_VALID_ACTION_LEVEL_ID        VARCHAR2(200);
     V_VALID_PORTFOLIO_ID           VARCHAR2(200);
     V_VALID_ACTION_LEVEL_KEY       VARCHAR2(200);
     V_VALID_DD_PARTITION_DATE      DATE;
     V_VALID_ND_KEY_HASH            VARCHAR2(200);
     V_VALID_RECORD_SOURCE_ID       VARCHAR2(200);
     V_VALID_DD_DATE                VARCHAR2(200);

     --To filter sprinklr/drishti value
     V_FLAG                         CHAR;
     V_CAMPAIGN_WAIT_TIME           NUMBER;
     V_EMD_BLOCK_CNT                NUMBER;
     V_TT_MASTERDISP_CNT            NUMBER;
     V_DIALER_SAF                   NUMBER;

BEGIN
     SAVEPOINT NBMB_ADDIN1;
     
     V_IF_COUNT:= 0;
     V_IF_RULE_CRITERIA:=0;
     V_IF_DYNAMIC_CSM_ENABLED:=0;
     V_IF_RULECRITERIA_FAILED:=0;
     
     V_VALID_RULE_ID := CASE WHEN p_RULE_ID IS NOT NULL THEN p_RULE_ID ELSE NULL END;
     V_VALID_DIALER_ACTION_TYPE_ID := CASE WHEN p_ACTION_TYPE_ID IS NOT NULL THEN p_ACTION_TYPE_ID ELSE NULL END;
     V_VALID_SDTIEBREAKER := CASE WHEN p_SD_TIEBREAKER IS NOT NULL THEN p_SD_TIEBREAKER ELSE NULL END;
     V_VALID_ACTION_LEVEL_ID := CASE WHEN p_ACTION_LEVEL_ID IS NOT NULL THEN p_ACTION_LEVEL_ID ELSE NULL END;  
     V_VALID_PORTFOLIO_ID := CASE WHEN p_PORTFOLIO_ID IS NOT NULL THEN p_PORTFOLIO_ID ELSE NULL END;    
     V_VALID_ACTION_LEVEL_KEY := CASE WHEN p_ACTION_LEVEL_KEY IS NOT NULL THEN p_ACTION_LEVEL_KEY ELSE NULL END;
     V_VALID_DD_PARTITION_DATE := CASE WHEN p_DD_PARTITION_DATE IS NOT NULL THEN p_DD_PARTITION_DATE ELSE NULL END;    
     V_VALID_ND_KEY_HASH := CASE WHEN p_ND_KEY_HASH IS NOT NULL THEN p_ND_KEY_HASH ELSE NULL END; 
     V_VALID_RECORD_SOURCE_ID := CASE WHEN p_RECORD_SOURCE_ID IS NOT NULL THEN p_RECORD_SOURCE_ID ELSE NULL END;     
     V_VALID_DD_DATE := CASE WHEN p_DD_DATE IS NOT NULL THEN p_DD_DATE ELSE NULL END;
     V_TDDATEKEY := REPLACE(TO_CHAR(P_DD_DATE,'YYYY-MM-DD HH24:MI:SS.FF3'),'-','');
     
     ----To check action_level enable flag (permanant disabled from backend)
     BEGIN
          SELECT IS_ENABLED INTO V_IF_DYNAMIC_CSM_ENABLED FROM DYNAMIC_CSM_CONFIG 
          WHERE CSM_ID = V_VALID_DIALER_ACTION_TYPE_ID 
          AND ACTION_LEVEL_ID = V_VALID_ACTION_LEVEL_ID
          AND ROWNUM =1;

     EXCEPTION
          WHEN NO_DATA_FOUND THEN NULL;
     END;
     
     ---If dialer is enabled in dynamic_csm_config
     IF (V_IF_DYNAMIC_CSM_ENABLED = 1) --1.6
     THEN 
          SELECT LCFGVALUE INTO V_DIALER_SAF FROM SYSTEMCONFIG WHERE SCFGVARIABLE = 'NBMB_DIAL_SPKLR_SAF_TIME' AND ROWNUM =1;
          
          BEGIN 
               SELECT CASE WHEN FAILED_REASON ='CRITERIA-FAILED' THEN 1 ELSE 0 END ,
                CASE WHEN (FAILED_REASON ='SAF-ISSUE-01' OR FAILED_REASON ='SAF-ISSUE-00' ) THEN 1  ELSE 0  END 
               INTO V_IF_RULECRITERIA_FAILED,V_IF_COUNT FROM TT_AUTO_DIALER_FLAG_EMPLOYEE
               WHERE SD_TIEBREAKER = V_VALID_SDTIEBREAKER AND  ACTION_LEVEL_ID=V_VALID_ACTION_LEVEL_ID AND ROWNUM = 1;
          
          EXCEPTION 
               WHEN NO_DATA_FOUND THEN V_IF_RULECRITERIA_FAILED:=0;V_IF_COUNT:=0;
          END;

          IF p_ACTION_ORDER = 0 AND NVL(V_IF_COUNT,0) = 1 
          THEN  --1.7
               V_IF_COUNT:=0;
               BEGIN   ---Fetching block autoaction details to be inserted into act as failed
                    SELECT B.LTYPE,B.LID,B.STEXT  
                    INTO V_AUTOACT_TYPE,V_AUTOACT_LACTID,V_AUTOACT_STEXT 
                    FROM AUTOACTIONSRULE A
                    INNER JOIN ACTIONSTEXT B
                    ON B.ACTION_LEVEL_ID=V_VALID_ACTION_LEVEL_ID AND A.LACTIONID=B.LTYPE  ---Generic Csm action_level_id input parameter
                    AND B.LSTATE=1 AND B.LSTATUS=2 AND B.LTYPE=0    
                    WHERE A.LRULEID=V_VALID_RULE_ID AND LACTIONID<>V_VALID_DIALER_ACTION_TYPE_ID ;
               EXCEPTION
                    WHEN NO_DATA_FOUND THEN NULL;
               END;

               IF ((CAST(V_AUTOACT_LACTID AS VARCHAR2) IS NOT NULL) AND  
               (CAST(V_AUTOACT_TYPE AS VARCHAR2) IS NOT NULL) AND   
               (CAST(V_AUTOACT_STEXT AS VARCHAR2) IS NOT NULL))    --1.8
               THEN
                    BEGIN
                         SELECT DE.MESSAGE_ID INTO V_LPRIOMESSAGE_ID FROM 
                         (  
                             SELECT EMD.MESSAGE_ID,EMD.ACTION_TYPE_ID,EMD.LSTATUS,
                             ROW_NUMBER() OVER (ORDER BY EMD.MESSAGE_ID DESC) AS ROW_NUM  
                             FROM EXTERNAL_MESSAGE_DATA EMD 
                             WHERE EMD.LPORTFOLIOID  = V_VALID_PORTFOLIO_ID  
                             AND   EMD.ACTION_TYPE_ID   IN (0,3,5)  
                             AND   EMD.ACTION_LEVEL_KEY = V_VALID_ACTION_LEVEL_KEY  
                             AND   EMD.ACTION_LEVEL_ID = V_VALID_ACTION_LEVEL_ID   
                             AND   EMD.SD_TIEBREAKER = V_VALID_SDTIEBREAKER  --Taking most recent block request of post dialer for update as 98
                             AND   EMD.DD_DATE   = V_VALID_DD_DATE   
                             AND EXISTS (SELECT 1 FROM AUTOACTIONSRULE AAR 
                                WHERE LRULEID=V_VALID_RULE_ID AND EMD.ACTION_TYPE_ID = AAR.LACTIONID AND ROWNUM=1)  
                         )DE WHERE DE.ROW_NUM = 1 ; 
                    
                    EXCEPTION
                         WHEN NO_DATA_FOUND THEN NULL;
                    END;

                    IF REGEXP_LIKE(V_LPRIOMESSAGE_ID, '^[[:digit:]]+$') 
                    THEN ---use validate function refer rule ovl
                    ----Post dialer block request update as 98 in case of saf issue 
                         UPDATE EXTERNAL_MESSAGE_DATA   
                         SET LSTATUS=98   
                         WHERE MESSAGE_ID=V_LPRIOMESSAGE_ID; 
                    END IF;

                    --Inserting saf info record into act
                    INSERT INTO ACT (ACTION_LEVEL_KEY, ACTION_LEVEL_ID, DTACTDATEKEY,TDDATEKEY, NREVID,  
                    LACTIONTYPE,  LACTIONID, LSTATE, LSTATUS, SACTACTION,  
                    SACTNOTES, SACTNOTES2, SREASON_CODE)  
                    VALUES  
                    (p_ACTION_LEVEL_KEY, p_ACTION_LEVEL_ID, SYSTIMESTAMP, V_TDDATEKEY , p_LREVID,             
                    V_AUTOACT_TYPE, V_AUTOACT_LACTID, 1, 2, V_AUTOACT_STEXT,  
                    'Failed due to diff in txn date and prm date > '|| V_DIALER_SAF||' mins-', NULL, NULL);  

                    SELECT COUNT(1) INTO V_IF_COUNT FROM TT_AUTO_DIALER_FLAG_EMPLOYEE 
                    WHERE SD_TIEBREAKER = V_VALID_SDTIEBREAKER
                    AND ACTION_LEVEL_ID=V_VALID_ACTION_LEVEL_ID AND FAILED_REASON ='SAF-ISSUE-00' AND ROWNUM=1;  

                    IF NVL(V_IF_COUNT,0) = 1
                    THEN
                         --Updating masterdisp to avoid disfunction button status 
                         UPDATE MASTERDISP   
                         SET STATE=0,STATUS=0  
                         WHERE  ACTION_LEVEL_ID = V_VALID_ACTION_LEVEL_ID 
                         AND ACTION_LEVEL_KEY = V_VALID_ACTION_LEVEL_KEY 
                         AND ACTIONID =0;  
                    END IF;
               END IF; --1.8
          ELSIF (p_ACTION_ORDER = 0 AND NVL(V_IF_RULECRITERIA_FAILED,0)=1) --1.7 ->ELSE IF
          THEN 
               V_IF_RULECRITERIA_FAILED:=0;
               BEGIN
                    SELECT B.LTYPE,B.LID,B.STEXT 
                    INTO V_AUTOACT_TYPE,V_AUTOACT_LACTID,V_AUTOACT_STEXT    
                    FROM AUTOACTIONSRULE A 
                    INNER JOIN ACTIONSTEXT B 
                    ON B.ACTION_LEVEL_ID=V_VALID_ACTION_LEVEL_ID AND A.LACTIONID=B.LTYPE  ---Generic Csm input action level id
                    AND B.LSTATE=1 AND B.LSTATUS=2 AND B.LTYPE=0    
                    WHERE A.LRULEID=V_VALID_RULE_ID AND LACTIONID<>V_VALID_DIALER_ACTION_TYPE_ID;---not in 451
               
               EXCEPTION
                    WHEN NO_DATA_FOUND THEN NULL;
               END;

               IF ((CAST(V_AUTOACT_LACTID AS VARCHAR2) IS NOT NULL) AND  
               (CAST(V_AUTOACT_TYPE AS VARCHAR2) IS NOT NULL) AND   
               (CAST(V_AUTOACT_STEXT AS VARCHAR2) IS NOT NULL))  --1.9
               THEN  
                    BEGIN
                         SELECT  DE.MESSAGE_ID INTO V_LPRIOMESSAGE_ID FROM    
                         (  
                             SELECT EMD.MESSAGE_ID,EMD.ACTION_TYPE_ID,EMD.LSTATUS,
                             ROW_NUMBER() OVER (ORDER BY EMD.MESSAGE_ID DESC) AS ROW_NUM  
                             FROM EXTERNAL_MESSAGE_DATA EMD 
                             WHERE EMD.LPORTFOLIOID  = V_VALID_PORTFOLIO_ID  
                             AND   EMD.ACTION_TYPE_ID   IN (0,3,5)  
                             AND   EMD.ACTION_LEVEL_KEY = V_VALID_ACTION_LEVEL_KEY  
                             AND   EMD.ACTION_LEVEL_ID = V_VALID_ACTION_LEVEL_ID   
                             AND   EMD.SD_TIEBREAKER = V_VALID_SDTIEBREAKER  
                             AND   EMD.DD_DATE   = V_VALID_DD_DATE   
                             AND EXISTS (SELECT 1 FROM AUTOACTIONSRULE AAR 
                                WHERE LRULEID=V_VALID_RULE_ID AND EMD.ACTION_TYPE_ID = AAR.LACTIONID AND ROWNUM=1)  
                         )DE WHERE DE.ROW_NUM = 1;
                    
                    EXCEPTION
                         WHEN NO_DATA_FOUND THEN NULL;
                    END;

                    IF REGEXP_LIKE(V_LPRIOMESSAGE_ID, '^[[:digit:]]+$') 
                    THEN 
                         UPDATE EXTERNAL_MESSAGE_DATA
                         SET LSTATUS=98   
                         WHERE MESSAGE_ID=V_LPRIOMESSAGE_ID;
                    END IF;

                    INSERT INTO ACT (ACTION_LEVEL_KEY, ACTION_LEVEL_ID, DTACTDATEKEY,TDDATEKEY, NREVID,  
                    LACTIONTYPE,  LACTIONID, LSTATE, LSTATUS, SACTACTION,  
                    SACTNOTES, SACTNOTES2, SREASON_CODE)  
                    VALUES  
                    (p_ACTION_LEVEL_KEY, p_ACTION_LEVEL_ID, SYSTIMESTAMP, V_TDDATEKEY , p_LREVID,  
                    V_AUTOACT_TYPE, V_AUTOACT_LACTID, 1, 2, V_AUTOACT_STEXT,  
                    'Failed due to Dialer Rule CRITERIA-FAILED-', NULL, NULL)  ;
               END IF;  --1.9
          END IF;  --1.7 END

          SELECT COUNT(1) INTO V_IF_COUNT FROM TT_AUTO_DIALER_FLAG_EMPLOYEE 
          WHERE SD_TIEBREAKER = V_VALID_SDTIEBREAKER 
          AND ACTION_LEVEL_ID=V_VALID_ACTION_LEVEL_ID AND ROWNUM =1;---action_level_id
          
          IF NVL(V_IF_COUNT,0)<> 1 --1.2
          THEN  
               V_IF_COUNT:=0;
               BEGIN
                    SELECT DD_APDATE INTO V_DD_APDATE FROM SHORTWINDOW   
                    WHERE DD_PARTITION_DATE = V_VALID_DD_PARTITION_DATE   
                    AND ND_KEY_HASH         = V_VALID_ND_KEY_HASH  
                    AND RECORD_SOURCE_ID   = V_VALID_RECORD_SOURCE_ID   
                    AND SD_TIEBREAKER       = V_VALID_SDTIEBREAKER AND ROWNUM=1;
               
               EXCEPTION
                    WHEN NO_DATA_FOUND THEN NULL;
               END;

               IF (p_DD_DATE < (V_DD_APDATE - V_DIALER_SAF/1440))     ---/*** SAF CRITERIA ***/  --1.1 
               THEN    
                    ---/*** To avoid button disfunctioned for PD
                    SELECT COUNT(1) INTO V_IF_COUNT FROM AUTOACTIONSRULE A 
                    INNER JOIN  TT_DIALER_AUTO_ACTION_PENDING_EMPLOYEE B 
                    ON A.LRULEID= B.RULE_ID AND A.LACTIONID=B.ACTION_ID  AND A.ACTION_ORDER= 0   
                    WHERE B.ACTION_LEVEL_ID  = V_VALID_ACTION_LEVEL_ID and     ---If pre dialer rule has satisfied on the transaction then flag will saf_issue-01 else saf-issue-00(saf-issue-00 means predialer rule is not there in transaction so we have to update masterdisp as 0,0)
                    B.ACTION_LEVEL_KEY   = V_VALID_ACTION_LEVEL_KEY and   
                    B.DD_PARTITION_DATE  = V_VALID_DD_PARTITION_DATE and       ---checking block request is attached with dialer or not---doubt
                    B.SD_TIEBREAKER   = V_VALID_SDTIEBREAKER AND   
                    B.ACTION_ID  = 0 AND ROWNUM=1 ;

                    IF NVL(V_IF_COUNT,0) = 1
                    THEN  
                         V_IF_COUNT := 0;
                         INSERT INTO TT_AUTO_DIALER_FLAG_EMPLOYEE (SD_TIEBREAKER,AUTO_DIALER_FLAG,FAILED_REASON,ACTION_LEVEL_ID,DD_PARTITION_DATE) 
                         VALUES (p_SD_TIEBREAKER,0,'SAF-ISSUE-01',p_action_level_id,V_VALID_DD_PARTITION_DATE); ---insert to avoid pd block request 
                    ELSE   
                         INSERT INTO TT_AUTO_DIALER_FLAG_EMPLOYEE (SD_TIEBREAKER,AUTO_DIALER_FLAG,FAILED_REASON,ACTION_LEVEL_ID,DD_PARTITION_DATE) 
                         VALUES (p_SD_TIEBREAKER,0,'SAF-ISSUE-00',p_action_level_id,V_VALID_DD_PARTITION_DATE) ;  ---insert to avoid pd block request
                    END IF; 

                    /*** FAILING POST DIALER BLOCK REQUEST DUE TO SAF ***/  
                    IF  p_ACTION_ORDER = 0                 
                    THEN
                    BEGIN
                         SELECT B.LTYPE,B.LID,B.STEXT  
                         INTO V_AUTOACT_TYPE,V_AUTOACT_LACTID,V_AUTOACT_STEXT
                         FROM AUTOACTIONSRULE A  
                         INNER JOIN ACTIONSTEXT B 
                         ON B.ACTION_LEVEL_ID=V_VALID_ACTION_LEVEL_ID AND  A.LACTIONID=B.LTYPE  ---Generic Csm p_action_id
                         AND B.LSTATE=1 AND B.LSTATUS=2 AND B.LTYPE=0   
                         WHERE A.LRULEID=V_VALID_RULE_ID AND LACTIONID<>V_VALID_DIALER_ACTION_TYPE_ID ; 
                                        
                    EXCEPTION
                         WHEN NO_DATA_FOUND THEN NULL;  
                    END;

                         IF ((CAST(V_AUTOACT_LACTID AS VARCHAR2) IS NOT NULL) AND  
                         (CAST(V_AUTOACT_TYPE AS VARCHAR2) IS NOT NULL) AND   
                         (CAST(V_AUTOACT_STEXT AS VARCHAR2) IS NOT NULL))   
                         THEN  
                              BEGIN
                                   SELECT  DE.MESSAGE_ID  INTO V_LPRIOMESSAGE_ID FROM    
                                   (SELECT EMD.MESSAGE_ID,EMD.ACTION_TYPE_ID,EMD.LSTATUS,ROW_NUMBER() OVER (ORDER BY EMD.MESSAGE_ID DESC) AS ROW_NUM  
                                   FROM EXTERNAL_MESSAGE_DATA EMD  
                                   WHERE EMD.LPORTFOLIOID  = V_VALID_PORTFOLIO_ID  
                                   AND   EMD.ACTION_TYPE_ID   IN (0,3,5)  
                                   AND   EMD.ACTION_LEVEL_KEY = V_VALID_ACTION_LEVEL_KEY  
                                   AND   EMD.ACTION_LEVEL_ID = V_VALID_ACTION_LEVEL_ID   
                                   AND   EMD.SD_TIEBREAKER = V_VALID_SDTIEBREAKER  
                                   AND   EMD.DD_DATE   = V_VALID_DD_DATE   
                                   AND EXISTS (SELECT 1 FROM AUTOACTIONSRULE AAR WHERE LRULEID=V_VALID_RULE_ID AND EMD.ACTION_TYPE_ID = AAR.LACTIONID AND ROWNUM=1)  
                                   )DE WHERE DE.ROW_NUM = 1  ;
                              
                              EXCEPTION
                                   WHEN NO_DATA_FOUND THEN NULL;
                              END;
     
                              IF REGEXP_LIKE(V_LPRIOMESSAGE_ID, '^[[:digit:]]+$') 
                              THEN 
                                   UPDATE EXTERNAL_MESSAGE_DATA   
                                   SET LSTATUS=98   
                                   WHERE MESSAGE_ID=V_LPRIOMESSAGE_ID ;
                              END IF;
                              
                              INSERT INTO ACT (ACTION_LEVEL_KEY, ACTION_LEVEL_ID, DTACTDATEKEY,TDDATEKEY, NREVID,  
                              LACTIONTYPE,  LACTIONID, LSTATE, LSTATUS, SACTACTION,  
                              SACTNOTES, SACTNOTES2, SREASON_CODE)  
                              VALUES  
                              (p_ACTION_LEVEL_KEY,p_ACTION_LEVEL_ID, SYSTIMESTAMP, V_TDDATEKEY , p_LREVID,  
                              V_AUTOACT_TYPE, V_AUTOACT_LACTID, 1, 2, V_AUTOACT_STEXT,  
                              'failed due to diff in txn date and prm date > '|| V_DIALER_SAF||' mins', NULL, NULL) ;  
     
                              SELECT COUNT(1) INTO V_IF_COUNT FROM  TT_AUTO_DIALER_FLAG_EMPLOYEE  WHERE   
                              SD_TIEBREAKER = V_VALID_SDTIEBREAKER AND ACTION_LEVEL_ID=V_VALID_ACTION_LEVEL_ID AND FAILED_REASON ='SAF-ISSUE-00';
                              
                              IF (NVL(V_IF_COUNT,0) = 1)
                              THEN
                                   UPDATE MASTERDISP   
                                   SET STATE=0,STATUS=0  
                                   WHERE  ACTION_LEVEL_ID = V_VALID_ACTION_LEVEL_ID AND  
                                   ACTION_LEVEL_KEY = V_VALID_ACTION_LEVEL_KEY AND  
                                   ACTIONID =0;
                              END  IF;
                         END IF;
                    END IF;
                    /*** FAILING POST DIALER BLOCK REQUEST DUE TO SAF ***/
                    
                    DELETE TT_DIALER_AUTO_ACTION_PENDING_EMPLOYEE WHERE   
                    ACTION_LEVEL_ID  = V_VALID_ACTION_LEVEL_ID and   
                    ACTION_LEVEL_KEY = V_VALID_ACTION_LEVEL_KEY and   
                    DD_PARTITION_DATE = V_VALID_DD_PARTITION_DATE and    
                    SD_TIEBREAKER  = V_VALID_SDTIEBREAKER ;
     
                    BEGIN
                         SELECT LID, STEXT INTO V_LACTION_TYPE_ID, V_SACT_ACTION  
                         FROM ACTIONSTEXT  
                         WHERE LTYPE = V_VALID_DIALER_ACTION_TYPE_ID  
                         AND ACTION_LEVEL_ID = V_VALID_ACTION_LEVEL_ID  
                         AND LSTATUS = 2  
                         AND LSTATE = 1 ;
                    
                    EXCEPTION
                         WHEN NO_DATA_FOUND THEN NULL;
                    END;
     
                    INSERT INTO ACT (ACTION_LEVEL_KEY, ACTION_LEVEL_ID, DTACTDATEKEY,TDDATEKEY, NREVID,  
                    LACTIONTYPE,  LACTIONID, LSTATE, LSTATUS, SACTACTION, ---Dialer reuqst act 
                    SACTNOTES, SACTNOTES2, SREASON_CODE)  
                    VALUES  
                    (p_ACTION_LEVEL_KEY, p_ACTION_LEVEL_ID, SYSTIMESTAMP, V_TDDATEKEY , p_LREVID,  
                    p_ACTION_TYPE_ID, V_LACTION_TYPE_ID, 1, 2, V_SACT_ACTION,  
                    'Failed due to diff in Txn Date and PRM Date > '|| V_DIALER_SAF||' Mins', NULL, NULL) ;  
     
               ELSE  ---Checking Rule id criteria     
     
                    SELECT COUNT(DISTINCT RULE_ID) INTO V_CNT_RULE_IDS 
                    FROM TT_DIALER_AUTO_ACTION_PENDING_EMPLOYEE 
                    WHERE ACTION_LEVEL_ID = V_VALID_ACTION_LEVEL_ID    
                    AND ACTION_LEVEL_KEY = V_VALID_ACTION_LEVEL_KEY    
                    AND DD_PARTITION_DATE = V_VALID_DD_PARTITION_DATE    
                    AND SD_TIEBREAKER = V_VALID_SDTIEBREAKER; 
     
                    SELECT COUNT(1) INTO V_IF_RULE_CRITERIA FROM  
                    (SELECT AAR1.LRULEID,COUNT(1) RULE_COUNT FROM AUTOACTIONSRULE AAR1 
                    WHERE  EXISTS (SELECT  1 FROM AUTOACTIONSRULE AAR2 WHERE     
                    EXISTS( SELECT 1 FROM TT_DIALER_AUTO_ACTION_PENDING_EMPLOYEE AP 
                    WHERE AP.ACTION_LEVEL_ID = V_VALID_ACTION_LEVEL_ID AND   
                    AP.ACTION_LEVEL_KEY   = V_VALID_ACTION_LEVEL_KEY AND   
                    AP.DD_PARTITION_DATE  = V_VALID_DD_PARTITION_DATE AND   
                    AP.SD_TIEBREAKER      = V_VALID_SDTIEBREAKER   
                    AND AAR2.LRULEID      = AP.RULE_ID and ROWNUM=1)  
                    AND AAR1.LRULEID= AAR2.LRULEID AND AAR2.LACTIONID IN (V_VALID_DIALER_ACTION_TYPE_ID) AND ROWNUM=1)  
                    AND AAR1.LACTIONID IN (V_VALID_DIALER_ACTION_TYPE_ID,0,3,5)   ----451
                    GROUP BY LRULEID HAVING COUNT(1)<=2) TP;
     
                    IF (V_IF_RULE_CRITERIA = V_CNT_RULE_IDS) 
                    THEN --1.0
                         BEGIN
                              SELECT LRULEID,CAMPAIGN_ID
                              INTO V_CHECK_RULE_ID ,V_CAMPAIGN_ID 
                              FROM (
                              SELECT  A.LRULEID,B.CAMPAIGN_ID ----Changed AUTO_ADDIN_TYPE to Campaig_id from campaign_master as config_id column added in campaign_master  
                              FROM AUTOACTIONSRULE A  
                              INNER JOIN CAMPAIGN_MASTER B ON A.AUTO_ADDIN_TYPE=B.CONFIG_ID
                              WHERE LRULEID IN (SELECT DISTINCT RULE_ID FROM AUTO_ACTION_PENDING  WHERE SD_TIEBREAKER = V_VALID_SDTIEBREAKER AND ACTION_ID=V_VALID_DIALER_ACTION_TYPE_ID) ----216,217,221,p_action_level_id
                              AND SHOST_VALUE =(SELECT MAX(CAST(SHOST_VALUE AS INT)) FROM AUTOACTIONSRULE AB WHERE   
                              LRULEID IN(SELECT DISTINCT RULE_ID FROM AUTO_ACTION_PENDING    
                              WHERE SD_TIEBREAKER = V_VALID_SDTIEBREAKER AND ACTION_ID=V_VALID_DIALER_ACTION_TYPE_ID))  
                              ORDER BY A.LRULEID) WHERE ROWNUM=1;
                         
                         EXCEPTION
                              WHEN NO_DATA_FOUND THEN NULL;
                         END;
     
                         INSERT INTO TT_AUTO_DIALER_FLAG_EMPLOYEE (SD_TIEBREAKER,MAX_RULEID,CAMPAIGN_ID,AUTO_DIALER_FLAG,FAILED_REASON,ACTION_LEVEL_ID,DD_PARTITION_DATE)
                         VALUES (p_SD_TIEBREAKER,V_CHECK_RULE_ID,V_CAMPAIGN_ID,1,'CRITERIA-PASS',P_ACTION_LEVEL_ID,V_VALID_DD_PARTITION_DATE); ----insert action_level_id
                         
                         DELETE TT_DIALER_AUTO_ACTION_PENDING_EMPLOYEE   
                         WHERE ACTION_LEVEL_ID = V_VALID_ACTION_LEVEL_ID and   
                         ACTION_LEVEL_KEY = V_VALID_ACTION_LEVEL_KEY and   
                         DD_PARTITION_DATE = V_VALID_DD_PARTITION_DATE and    
                         SD_TIEBREAKER = V_VALID_SDTIEBREAKER;
     
                    ELSE   ----If rule criteria getting filed
                    /*** FAILING POST DIALER BLOCK REQUEST DUE TO RULE CRITERIA FAILED. ***/  
                         IF  p_ACTION_ORDER = 0 
                         THEN 
                              BEGIN
                                   SELECT  B.LTYPE,B.LID,B.STEXT  
                                   INTO V_AUTOACT_TYPE,V_AUTOACT_LACTID,V_AUTOACT_STEXT
                                   FROM AUTOACTIONSRULE A    
                                   INNER JOIN ACTIONSTEXT B
                                   ON B.ACTION_LEVEL_ID=V_VALID_ACTION_LEVEL_ID AND  A.LACTIONID=B.LTYPE  ---Generic Csm p_action_level_id
                                   AND B.LSTATE=1 AND B.LSTATUS=2 AND B.LTYPE=0   
                                   WHERE A.LRULEID=V_VALID_RULE_ID AND LACTIONID<>V_VALID_DIALER_ACTION_TYPE_ID   AND ROWNUM=1;--- 451
                         
                              EXCEPTION
                                   WHEN NO_DATA_FOUND THEN NULL;
                              END;
     
                              IF ((CAST(V_AUTOACT_LACTID AS VARCHAR2) IS NOT NULL) AND  
                              (CAST(V_AUTOACT_TYPE AS VARCHAR2) IS NOT NULL) AND   
                              ( CAST(V_AUTOACT_STEXT AS VARCHAR2) IS NOT NULL)) 
                              THEN  
                                   BEGIN
                                        SELECT  DE.MESSAGE_ID
                                        INTO V_LPRIOMESSAGE_ID
                                        FROM    
                                        (  
                                        SELECT EMD.MESSAGE_ID,EMD.ACTION_TYPE_ID,EMD.LSTATUS,ROW_NUMBER() OVER (ORDER BY EMD.MESSAGE_ID DESC) AS ROW_NUM  
                                        FROM EXTERNAL_MESSAGE_DATA EMD   
                                        WHERE EMD.LPORTFOLIOID  = V_VALID_PORTFOLIO_ID  
                                        AND   EMD.ACTION_TYPE_ID   IN (0,3,5)  
                                        AND   EMD.ACTION_LEVEL_KEY = V_VALID_ACTION_LEVEL_KEY  
                                        AND   EMD.ACTION_LEVEL_ID = V_VALID_ACTION_LEVEL_ID   
                                        AND   EMD.SD_TIEBREAKER = V_VALID_SDTIEBREAKER  
                                        AND   EMD.DD_DATE   = V_VALID_DD_DATE   
                                        AND EXISTS (SELECT 1 FROM AUTOACTIONSRULE AAR  WHERE LRULEID=V_VALID_RULE_ID AND EMD.ACTION_TYPE_ID = AAR.LACTIONID 
                                        AND ROWNUM=1)  
                                        )DE WHERE DE.ROW_NUM = 1 ;
                                   
                                   EXCEPTION
                                        WHEN NO_DATA_FOUND THEN NULL;
                                   END;
     
                                   IF REGEXP_LIKE(V_LPRIOMESSAGE_ID, '^[[:digit:]]+$') 
                                   THEN 
                                        UPDATE EXTERNAL_MESSAGE_DATA   
                                        SET LSTATUS=98   
                                        WHERE MESSAGE_ID=V_LPRIOMESSAGE_ID;
                                   END IF;
                                   
                                   INSERT INTO ACT (ACTION_LEVEL_KEY, ACTION_LEVEL_ID, DTACTDATEKEY,TDDATEKEY, NREVID,  
                                   LACTIONTYPE,  LACTIONID, LSTATE, LSTATUS, SACTACTION,  
                                   SACTNOTES, SACTNOTES2, SREASON_CODE)  
                                   VALUES  
                                   (p_ACTION_LEVEL_KEY, p_ACTION_LEVEL_ID, SYSTIMESTAMP, V_TDDATEKEY , p_LREVID,  
                                   V_AUTOACT_TYPE, V_AUTOACT_LACTID, 1, 2, V_AUTOACT_STEXT,  
                                   'Failed due to Dialer Rule CRITERIA-FAILED.', NULL, NULL) ;
                              END  IF;    
                         END IF;
                         
                         /*** FAILING POST DIALER BLOCK REQUEST DUE TO RULE CRITERIA FAILED.  ***/
                         INSERT INTO TT_AUTO_DIALER_FLAG_EMPLOYEE (SD_TIEBREAKER,AUTO_DIALER_FLAG,FAILED_REASON,ACTION_LEVEL_ID,DD_PARTITION_DATE) 
                         VALUES (p_SD_TIEBREAKER,0,'CRITERIA-FAILED',p_action_level_id,V_VALID_DD_PARTITION_DATE);--- insert p_action_level_id
                         
                         DELETE TT_DIALER_AUTO_ACTION_PENDING_EMPLOYEE   
                         WHERE ACTION_LEVEL_ID = V_VALID_ACTION_LEVEL_ID and   
                         ACTION_LEVEL_KEY = V_VALID_ACTION_LEVEL_KEY and   
                         DD_PARTITION_DATE = V_VALID_DD_PARTITION_DATE and   
                         SD_TIEBREAKER = V_VALID_SDTIEBREAKER  ;
                         
                         BEGIN
                              SELECT LID,STEXT INTO V_LACTION_TYPE_ID, V_SACT_ACTION
                              FROM ACTIONSTEXT  
                              WHERE LTYPE = V_VALID_DIALER_ACTION_TYPE_ID  
                              AND ACTION_LEVEL_ID = V_VALID_ACTION_LEVEL_ID  
                              AND LSTATUS = 2  
                              AND LSTATE = 1  ;
                         
                         EXCEPTION
                              WHEN NO_DATA_FOUND THEN NULL;
                         END;
     
                         INSERT INTO ACT (ACTION_LEVEL_KEY, ACTION_LEVEL_ID, DTACTDATEKEY,TDDATEKEY, NREVID,  
                         LACTIONTYPE,  LACTIONID, LSTATE, LSTATUS, SACTACTION,  
                         SACTNOTES, SACTNOTES2, SREASON_CODE)  
                         VALUES  
                         (p_ACTION_LEVEL_KEY, p_ACTION_LEVEL_ID,SYSTIMESTAMP, V_TDDATEKEY , p_LREVID,  
                         p_ACTION_TYPE_ID, V_LACTION_TYPE_ID, 1, 2, V_SACT_ACTION,  
                         'Failed due to Dialer Rule CRITERIA-FAILED..', NULL, NULL);
                    END IF; --1.0     
               END IF;    --saf/rule criteria check end   --1.1
          END IF; --1.2

          --**rather than fetching three times , handling it in single table fetch.
          BEGIN
               SELECT AUTO_DIALER_FLAG ,NVL(MAX_RULEID,0), NVL(CAMPAIGN_ID,0) INTO V_AUTO_DIALER_FLAG ,V_MAX_RULEID,V_INS_CAMPAIGN_ID 
               FROM TT_AUTO_DIALER_FLAG_EMPLOYEE WHERE SD_TIEBREAKER = V_VALID_SDTIEBREAKER and ACTION_LEVEL_ID=V_VALID_ACTION_LEVEL_ID;--- check p_action_level_id
          
          EXCEPTION
               WHEN NO_DATA_FOUND THEN V_AUTO_DIALER_FLAG:= NULL;V_MAX_RULEID:=NULL;V_INS_CAMPAIGN_ID:=NULL;
          END;

          /** DELETING LOWEST PRIORITY RULES AUTO ACTIONS **/  
          IF (V_AUTO_DIALER_FLAG = 1)
          THEN  
               BEGIN
                    SELECT  LISTAGG(Z.MESSAGE_ID,',') WITHIN GROUP  (order by Z.MESSAGE_ID) 
                    INTO V_LPRIOMESSAGE_ID -------------fecthig ALL comma separated msgID except Highest Priority RuleID of Dialer
                    FROM
                    (
                    SELECT EMD.MESSAGE_ID FROM EXTERNAL_MESSAGE_DATA EMD
                    WHERE EMD.LPORTFOLIOID  = V_VALID_PORTFOLIO_ID  
                    AND   EMD.ACTION_TYPE_ID     <> V_VALID_DIALER_ACTION_TYPE_ID  --p_actype_id
                    AND   EMD.ACTION_LEVEL_KEY = V_VALID_ACTION_LEVEL_KEY  
                    AND   EMD.ACTION_LEVEL_ID = V_VALID_ACTION_LEVEL_ID   -------------fecthig autoaction(block/ice/watch) which is not available in inqualified ruleid 
                    AND   EMD.SD_TIEBREAKER  = V_VALID_SDTIEBREAKER  
                    AND   EMD.DD_DATE   = V_VALID_DD_DATE   
                    AND  NOT EXISTS (SELECT 1 FROM AUTOACTIONSRULE AAR  WHERE LRULEID=V_MAX_RULEID AND EMD.ACTION_TYPE_ID = AAR.LACTIONID AND ROWNUM=1)
                    UNION ALL
                    SELECT DE.MESSAGE_ID
                    FROM
                    (  
                    SELECT MESSAGE_ID,EMD.ACTION_TYPE_ID,EMD.LSTATUS,ROW_NUMBER() OVER (ORDER BY EMD.LSTATUS DESC) AS ROW_NUM  
                    FROM EXTERNAL_MESSAGE_DATA EMD  
                    WHERE EMD.LPORTFOLIOID      = V_VALID_PORTFOLIO_ID  
                    AND   EMD.ACTION_TYPE_ID   <> V_VALID_DIALER_ACTION_TYPE_ID  --p_actype_id
                    AND   EMD.ACTION_LEVEL_KEY = V_VALID_ACTION_LEVEL_KEY  
                    AND   EMD.ACTION_LEVEL_ID = V_VALID_ACTION_LEVEL_ID  --- fetching all block request except any 1 
                    AND   EMD.SD_TIEBREAKER = V_VALID_SDTIEBREAKER  
                    AND   EMD.DD_DATE   = V_VALID_DD_DATE   
                    AND EXISTS (SELECT 1 FROM AUTOACTIONSRULE AAR WHERE LRULEID=V_MAX_RULEID AND EMD.ACTION_TYPE_ID = AAR.LACTIONID AND ROWNUM=1)
                    )DE WHERE DE.ROW_NUM > 1 ) Z ;
               
               EXCEPTION
                    WHEN NO_DATA_FOUND THEN NULL;
               END;

               IF LENGTH(V_LPRIOMESSAGE_ID) > 0
               THEN 
                    V_SQL_QUERY  :=   ' DELETE FROM EXTERNAL_MESSAGE_DATA'  
                    ||' WHERE MESSAGE_ID IN (:1)';  ---deleting all fetched block request
                    --||' WHERE MESSAGE_ID IN (' || V_LPRIOMESSAGE_ID || ')';  ---deleting all fetched block request 
               
                    BEGIN
                         EXECUTE IMMEDIATE V_SQL_QUERY USING V_LPRIOMESSAGE_ID;
                    EXCEPTION
                         WHEN OTHERS THEN PP_MAKE_AUDIT_ENTRY ( V_SQL_QUERY||'- Dynamic_Lower_Message_ID_Delete',11,59);
                    END;
               
                    ----- Changes for Masterdisp update started -----ADDED BY VAIBHAV ON 14FEB2024
                    SELECT COUNT(1) INTO V_EMD_BLOCK_CNT FROM EXTERNAL_MESSAGE_DATA WHERE SD_TIEBREAKER = V_VALID_SDTIEBREAKER
                    AND ACTION_TYPE_ID IN (0);                
                    
                    IF (V_EMD_BLOCK_CNT = 0) 
                    THEN
                         SELECT COUNT(1) INTO V_TT_MASTERDISP_CNT FROM TT_MASTERDISP_EMPLOYEE_DIALER_BLOCK_STATUS
                         WHERE ACTION_LEVEL_KEY = V_VALID_ACTION_LEVEL_KEY AND SD_TIEBREAKER = V_VALID_SDTIEBREAKER AND ROWNUM =1;

                         BEGIN
                              IF (V_TT_MASTERDISP_CNT =1) 
                              THEN
                                   MERGE INTO MASTERDISP A ---(UPDATING MASTERDISP USING TT_MASTERDISP TABLE)
                                   USING   TT_MASTERDISP_EMPLOYEE_DIALER_BLOCK_STATUS B 
                                   ON( A.ACTION_LEVEL_KEY = B.ACTION_LEVEL_KEY 
                                   AND A.ACTION_LEVEL_ID = B.ACTION_LEVEL_ID 
                                   AND A.ACTIONID = B.ACTIONID
                                   AND B.SD_TIEBREAKER = V_VALID_SDTIEBREAKER)  
                                   WHEN MATCHED THEN
                                   UPDATE SET A.STATE = B.STATE, A.STATUS=B.STATUS,A.ACTIONDATE = B.ACTIONDATE 
                                   ,A.MOSTRECENTTXNDATE = B.MOSTRECENTTXNDATE;
                              
                              ELSE 
                                   DELETE FROM MASTERDISP WHERE ACTION_LEVEL_KEY = V_VALID_ACTION_LEVEL_KEY AND
                                   ACTION_LEVEL_ID = V_VALID_ACTION_LEVEL_ID AND ACTIONID = 0;
                              END IF;
                         EXCEPTION
                              WHEN OTHERS THEN NULL;
                         END;
                    END IF;
               ----- Changes for Masterdisp update ended-----    
               END IF;
          END IF;
          
          /** DELETING LOWEST PRIORITY RULES AUTO ACTIONS **/
          IF (V_AUTO_DIALER_FLAG =1) 
          THEN --CHECK AUTODIALERFLAG =1
               IF p_ACTION_ORDER = 0 
               THEN ----POST DIALER FLAG  
                    IF (p_RULE_ID = V_MAX_RULEID)
                    THEN ----CHECKING FOR HIGHER PRIORITY AUTOACTION  
                         BEGIN
                              SELECT  LACTIONID INTO  V_OTHER_ACTION_TYPE_ID FROM AUTOACTIONSRULE 
                              WHERE LRULEID = V_VALID_RULE_ID AND LACTIONID <> V_VALID_DIALER_ACTION_TYPE_ID  ;---p_auto_action_id
                         EXCEPTION
                              WHEN NO_DATA_FOUND THEN NULL;
                         END;

                         BEGIN
                              SELECT  MESSAGE_ID INTO   V_LPRIOMESSAGE_ID  FROM EXTERNAL_MESSAGE_DATA  WHERE   
                              ACTION_LEVEL_KEY = V_VALID_ACTION_LEVEL_KEY  
                              AND  ACTION_LEVEL_ID  = V_VALID_ACTION_LEVEL_ID  
                              AND  ACTION_TYPE_ID  = V_OTHER_ACTION_TYPE_ID  ---holding post dailer block reques
                              AND  LPORTFOLIOID  = V_VALID_PORTFOLIO_ID   
                              AND  SD_TIEBREAKER  = V_VALID_SDTIEBREAKER  
                              AND  DD_DATE    = V_VALID_DD_DATE
                              AND ROWNUM=1;
                         EXCEPTION
                              WHEN NO_DATA_FOUND THEN NULL;
                         END;

                         ---,SNOTE = SNOTE+'-Auto Action wrt Highest Priority Auto Dialer,Ignore other Auto Actions' As Per Sid     
                         IF  REGEXP_LIKE(V_LPRIOMESSAGE_ID, '^[[:digit:]]+$')
                         THEN 
                              UPDATE  EXTERNAL_MESSAGE_DATA   
                              SET LSTATUS = 99  
                              WHERE  MESSAGE_ID = V_LPRIOMESSAGE_ID AND ROWNUM=1;
                         END IF;

                         SELECT COUNT(1) INTO V_IF_COUNT FROM ACTIONSTYPE_ACTION_LEVEL_EMM ATALE  
                         WHERE ATALE.ACTION_LEVEL_ID = V_VALID_ACTION_LEVEL_ID  
                         AND (ATALE.PORTFOLIO_ID  = V_VALID_PORTFOLIO_ID OR ATALE.PORTFOLIO_ID IS NULL)  
                         AND  ACTION_TYPE_ID   = V_OTHER_ACTION_TYPE_ID AND ROWNUM=1;

                         IF NVL( V_IF_COUNT,0) <> 1 
                         THEN
                              UPDATE MASTERDISP  
                              SET STATE = 0,STATUS = 0  
                              WHERE ACTION_LEVEL_ID = V_VALID_ACTION_LEVEL_ID            
                              AND   ACTION_LEVEL_KEY = V_VALID_ACTION_LEVEL_KEY  
                              AND   ACTIONID   = V_OTHER_ACTION_TYPE_ID  ;
                         END IF;
                    END IF; ----CHECKING FOR HIGHER PRIORITY AUTOACTION
               END IF; ----POST DIALER FLAG  
          END IF; --CHECK AUTODIALERFLAG =1

          /* INSERTING HIGHEST PRIORITY RULS'S AUTO DIALER ACTION_ID ,AUTO_DIALER_ACTION_TYPE_ID =451 */  
          IF(V_AUTO_DIALER_FLAG = 1)
          THEN  --1.5 
               IF (p_RULE_ID = V_MAX_RULEID) 
               THEN ----CHECKING FOR HIGHER PRIORITY AUTOACTION  --1.4
                    BEGIN
                         SELECT L10.L10N_VALUE INTO V_RULE_NAME  FROM RULEQUE RQ , L10N_PROPERTY L10   
                         WHERE RQ.LID = V_MAX_RULEID AND L10.LOCALE_ID='en_US'  AND RQ.SNAME = L10.L10N_PROPERTY_ID;
                    
                    EXCEPTION
                         WHEN NO_DATA_FOUND THEN NULL;
                    END;

                    --To check for Sprinklr changes start
                    BEGIN
                         SELECT FLAG, WAIT_TIME INTO V_FLAG, V_CAMPAIGN_WAIT_TIME FROM CAMPAIGN_MASTER C 
                         WHERE C.CAMPAIGN_PRIORITY = (SELECT SHOST_VALUE FROM AUTOACTIONSRULE A WHERE A.LRULEID = V_MAX_RULEID 
                         AND A.LACTIONID = V_VALID_DIALER_ACTION_TYPE_ID)
                         AND C.ACTION_LEVEL_ID=V_VALID_ACTION_LEVEL_ID;
                    
                    EXCEPTION 
                         WHEN NO_DATA_FOUND THEN NULL;
                    END;
                    --To check for Sprinklr changes end

                    V_RULE_NAME := CASE WHEN V_FLAG='S' THEN V_RULE_NAME
                    ELSE V_RULE_NAME||'-'||p_SD_TIEBREAKER END; 

                    INSERT INTO EXTERNAL_MESSAGE_DATA  
                    (MESSAGE_ID,ACTION_LEVEL_ID,LPORTFOLIOID,  
                    ACTION_TYPE_ID,ACTION_LEVEL_KEY, LSTATE,LSTATUS,  
                    DD_PARTITION_DATE,ND_KEY_HASH, ND_RECORD_SOURCE_ID,SD_TIEBREAKER,  
                    DD_DATE ,TDDATEKEY,DTREQUESTED, DTSUBMITTED,DTCOMPLETED,DTMOSTRECENTTXN,  
                    DTENDDATE,LREVID,LERRID,SEMSG,SHOST_DATA,SREASON_CODE,  
                    SD_SEQ_NUM,SD_MBR_NUM, SM_FIID,SM_BIN, SNOTE,SNOTE2, PRCSID,TRACKING_ID)  --Added for sprinklr
                    VALUES  
                    (EXTERNAL_MESSAGE_DATA_SEQ.NEXTVAL,p_ACTION_LEVEL_ID, p_PORTFOLIO_ID,  
                    p_ACTION_TYPE_ID, p_ACTION_LEVEL_KEY, 1, 1,  
                    p_DD_PARTITION_DATE, p_ND_KEY_HASH, p_RECORD_SOURCE_ID,p_SD_TIEBREAKER
                    ,p_DD_DATE, V_TDDATEKEY,SYSTIMESTAMP,NULL,NULL,p_DD_DATE
                    , p_ACTION_DATETIME, p_LREVID, NULL, NULL, V_MAX_RULEID, V_INS_CAMPAIGN_ID,
                    NULL, NULL, p_SM_FIID, p_SM_BIN,V_RULE_NAME,p_ACTION_ORDER, V_FLAG, V_CAMPAIGN_WAIT_TIME);  --Added for sprinklr
                    
                    INSERT  INTO  TT_DIALER_CRITERIA_FLAG_EMPLOYEE   
                    (ACTION_LEVEL_KEY,SD_TIEBREAKER,FLAG,ACTION_ORDER,RULE_ID,ACTION_LEVEL_ID,PRCSID,DD_PARTITION_DATE)
                    VALUES (p_ACTION_LEVEL_KEY,p_SD_TIEBREAKER,'N',p_ACTION_ORDER,V_MAX_RULEID,p_ACTION_LEVEL_ID,V_FLAG,p_DD_PARTITION_DATE);   --- It has checked for handling autoclear alerts it has sent to the dialer then only 
                    ---Autoclear proc will run 'N' flag will get update in polling proc after request send
               END IF; --1.4
          END IF; --1.5
     END IF; --1.6
 -- commit;
EXCEPTION
    WHEN OTHERS THEN
    --- rollback;
    ROLLBACK TO SAVEPOINT NBMB_ADDIN1;

    V_MESSAGE := SUBSTR(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE||' SQLERRM: '||SQLERRM, 1, 2000);
    PP_MAKE_AUDIT_ENTRY (V_MESSAGE,11,59); 
    COMMIT; 

END ;
