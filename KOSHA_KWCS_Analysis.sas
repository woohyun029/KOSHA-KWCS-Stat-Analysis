/* ============================================================
   02. 탐색적 데이터 분석 (EDA)
   데이터 : 제7차 근로환경조사(2023), 임금근로자 30,012명 x 250개 변수
   목적   : 복합표본 설계를 반영한 종속변수 분포 확인
   ============================================================ */

proc import datafile='/home/u63652680/KWCS/kwcs2023_clean.csv'
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

/* ------------------------------------------------------------
   2.2-1 종속변수와의 순위상관 (Spearman)
     변수 유형이 순서형이므로 Pearson이 아닌 Spearman을 쓴다.
     상위 상관 변수만 예시로 지정한다.
   ------------------------------------------------------------ */
proc corr data=work.kwcs spearman nosimple;
    var wbalance weng1 weng2 wstat1 wsituation11 safeinform
        emp_manaqual1 heal_cond heal_risk hazard_erg3 income_bal;
    with satisfaction;
run;

/* ------------------------------------------------------------
   2.2-2 신뢰도 분석 (Cronbach's alpha)
     alpha  : 문항들이 하나의 개념을 재고 있는지 판단
     nomiss : 완전응답자만 사용 (Python 결과와 맞추기 위함)
     출력의 'Cronbach Coefficient Alpha with Deleted Variable'에서
     특정 문항을 뺐을 때 alpha가 오르면 그 문항이 척도를 해치는 것이다.
   ------------------------------------------------------------ */
proc corr data=work.kwcs alpha nomiss nosimple;
    var wsituation1-wsituation14;
    title '업무상황 14문항 신뢰도';
run;

proc corr data=work.kwcs alpha nomiss nosimple;
    var who1-who5;
    title 'WHO-5 정신건강 5문항 신뢰도';
run;

proc corr data=work.kwcs alpha nomiss nosimple;
    var hazard_phy1-hazard_phy9;
    title '물리적 위험노출 9문항 신뢰도';
run;

/* alpha가 낮은 블록 - 역방향 문항 진단 */
proc corr data=work.kwcs alpha nomiss nosimple;
    var hazard_erg1 hazard_erg2 hazard_erg3
        hazard_erg4 hazard_erg5 hazard_erg6;
    title '인간공학 위험 6문항 - alpha 0.41, 역방향 문항 탐색';
run;

proc corr data=work.kwcs alpha nomiss nosimple;
    var condim1-condim6;
    title '작업특성 6문항 - alpha 0.58, 역방향 문항 탐색';
run;
title;