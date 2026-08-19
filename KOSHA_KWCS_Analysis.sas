/* ============================================================
   02. 탐색적 데이터 분석 (EDA)
   데이터 : 제7차 근로환경조사(2023), 임금근로자 30,012명 x 250개 변수
   목적   : 복합표본 설계를 반영한 종속변수 분포 확인
   ============================================================ */

proc import datafile='/home/u63652680/kwcs2023_clean.csv'
    out=work.kwcs dbms=csv replace;
    guessingrows=max;   /* 250개 열, 타입 추론 잘림 방지 */
run;

proc contents data=work.kwcs varnum;
run;


/* ------------------------------------------------------------
   2.1-1 비가중 분포
     단순 빈도. 설계를 무시하므로 모집단 대표성이 없다.
     비교 기준으로만 사용한다.
   ------------------------------------------------------------ */
proc freq data=work.kwcs;
    tables satisfaction / nocum;
run;


/* ------------------------------------------------------------
   2.1-2 가중 분포 (복합표본)
     strata  : 조사구층 (55개)
     cluster : 조사구 = 1차 추출단위 (4,831개)
     weight  : wt2 = 최종 확대가중치
     Sum of Weights 가 모집단 추정치(약 2,194만 명)로 복원된다.
   ------------------------------------------------------------ */
proc surveyfreq data=work.kwcs;
    strata  stratification;
    cluster district;
    weight  wt2;
    tables  satisfaction / cl;
run;