Hi Sashi,

This is regarding HDFC Sprinklr Intent Overwrite — Change 1: sd_prod_ind = A/D.

Our planned approach: the vanilla column SD_REAL_TIME_DISPOSITION (SHORTWINDOW/DETAIL) would carry the PRM RT decision for each transaction. In DYNAMIC_CSM_CONFIG.CSM_SELECT_COLUMN (all 6 dialer rows — 215/210/300/310/451/452), we add a CASE on that column to populate sd_prod_ind in the JF payload:

CASE WHEN SD_REAL_TIME_DISPOSITION = '<decline value>' THEN 'D' ELSE 'A' END

The ELSE covers Approve, RT timeout, and pure-NRT (null) cases → ‘A’, as per SSD 3.1. No proc/batch changes needed for this.

Flow:
Txn → PRM RT decides (Approve/Decline)
    → NRT feed carries the RT decision
    → AG IF-mapping writes it to SHORTWINDOW/DETAIL.SD_REAL_TIME_DISPOSITION
    → Polling proc (CSM_SELECT_COLUMN CASE) → sd_prod_ind = 'A'/'D'
    → EMD_DIALER_REQUEST → batch → OBP → JF request to Sprinklr


Please confirm:

Is this approach correct?
Currently SD_REAL_TIME_DISPOSITION is NULL for all transactions in our environment — how is the RT disposition planned to reach NRT transaction data (feed field + IF-format mapping)? Who populates it — bank feed or AG config?
What exact value will it carry for Decline (so we can finalize the CASE)?
Should we use SD_REAL_TIME_DISPOSITION or SD_REAL_TIME_RULE_DISPOSITION?


Testing will need fresh transactions fired through AG with the field populated, since existing rows are NULL (defaulting to ‘A’).

Thanks,
Kshitij
