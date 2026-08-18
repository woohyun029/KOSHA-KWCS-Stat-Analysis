/* ============================================================
   02. EDA - 데이터 탐색
   데이터 : 제7차 근로환경조사(2023), 임금근로자 30,012명 x 250개 변수
   목적   : 복합표본 설계를 반영한 종속변수 분포 확인
   ============================================================ */

proc import datafile='/home/u63652680/KWCS/kwcs2023_clean.csv'
    out=work.kwcs dbms=csv replace;
    guessingrows=max;    /* 250개 열, 잘림 방지 */
run;

proc contents data=work.kwcs varnum; run;

/* --- 비가중 분포 --- */
proc freq data=work.kwcs;
    tables satisfaction / nocum;
run;

/* --- 가중 분포 : 층화·집락·가중치 반영 --- */
proc surveyfreq data=work.kwcs;
    strata  stratification;   /* 조사구층 */
    cluster district;         /* 조사구 = 1차 추출단위 */
    weight  wt2;              /* 최종 확대가중치 */
    tables  satisfaction / cl;
run;
