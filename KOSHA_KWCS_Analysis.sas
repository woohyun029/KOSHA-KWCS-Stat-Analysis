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

/* ------------------------------------------------------------
   2.2-4 탐색적 요인분석 (PROC FACTOR)

     method=principal : 주성분 방식으로 요인 추출
     rotate=varimax   : 직교회전. 요인 간 상관을 0으로 두고
                        각 문항이 한 요인에만 크게 적재되도록 축을 돌린다
     mineigen=1       : Kaiser 기준. 고유값 1 초과 요인만 유지
     scree            : 스크리 도표. 고유값이 꺾이는 지점을 눈으로 확인
     nfactors=n       : 요인 수를 직접 지정 (mineigen과 함께 쓰면 우선 적용)

     출력에서 볼 것
       (1) Eigenvalues of the Correlation Matrix - 고유값과 누적 설명분산
       (2) Rotated Factor Pattern - 회전 후 적재량. 절대값 0.4 이상을 소속으로 본다
       (3) Scree Plot - 꺾이기 직전까지가 유지할 요인 수
   ------------------------------------------------------------ */

proc factor data=work.kwcs
        method=principal rotate=varimax mineigen=1 scree;
    var wsituation1-wsituation14;
    title '업무상황 14문항 - 요인분석';
run;

proc factor data=work.kwcs method=principal rotate=varimax mineigen=1;
    var wstat1-wstat7;
    title 'wstat 업무동의 7문항';
run;

proc factor data=work.kwcs method=principal rotate=varimax mineigen=1;
    var weng1-weng5;
    title 'weng 직무열의 5문항 - alpha 0.732 였으나 차원 확인 필요';
run;

proc factor data=work.kwcs method=principal rotate=varimax mineigen=1;
    var hazard_phy1-hazard_phy9;
    title 'hazard_phy 물리위험 9문항';
run;

proc factor data=work.kwcs method=principal rotate=varimax mineigen=1;
    var wtime_length1-wtime_length5;
    title 'wtime_length 근무형태 5문항';
run;

proc factor data=work.kwcs method=principal rotate=varimax mineigen=1;
    var heal_prob1 heal_prob2 heal_prob3 heal_prob4
        heal_prob5 heal_prob6 heal_prob8;
    title 'heal_prob 건강문제 7문항';
run;

/* 1요인으로 예상되는 블록 - 검증용. 요인이 1개면 회전이 생략된다 */
proc factor data=work.kwcs method=principal rotate=varimax mineigen=1;
    var who1-who5;
    title 'WHO-5 - 1요인 확인';
run;
title;

/* ------------------------------------------------------------
   2.3-4 요인분석 결과 해석

   [로그의 WARNING 은 정상이다]
     "n of 30012 observations omitted due to missing values"
     PROC FACTOR 는 목록별 제거(listwise deletion)를 사용한다.
     문항 중 하나라도 결측이면 해당 관측치를 통째로 제외한다.
     Python 의 dropna() 와 동일한 동작이며, 제외 건수가
     7개 블록 모두 Python 표본 크기와 정확히 일치했다.
       wsituation   4,185 제외 -> 25,827
       wstat        2,501 제외 -> 27,511
       weng            44 제외 -> 29,968
       hazard_phy     181 제외 -> 29,831
       wtime_length    96 제외 -> 29,916
       heal_prob       92 제외 -> 29,920
       who             42 제외 -> 29,970

   [로그의 NOTE 읽는 법]
     "n factors will be retained by the MINEIGEN criterion"
        고유값 1 초과 요인 개수. 요인 수 판정 결과다.
     "Rotation converged. Criterion changed ... in n cycles"
        베리맥스 회전이 정상 수렴했다는 뜻. 반복 횟수는 의미 없다.
     "Rotation not possible with 1 factor"
        요인이 1개면 돌릴 축이 없다. 1차원 척도임이 확인된 것으로,
        WHO-5 에서 예상대로 출력되었다.

   [출력 표에서 볼 것]
     (1) Eigenvalues of the Correlation Matrix
         고유값과 누적 설명분산. 1을 넘는 개수가 요인 수다.
     (2) Rotated Factor Pattern
         회전 후 적재량. 절대값 0.4 이상을 소속 요인으로 본다.
         부호는 무시한다. 요인 방향은 계산 과정에서 임의로 정해지므로
         Python 이 -0.87, SAS 가 +0.87 이어도 같은 결과다.
         두 요인 모두 0.4 이상이면 교차적재이며 해석에 주의한다.
     (3) Scree Plot
         고유값이 급격히 꺾이다 완만해지는 직전까지가 유지할 요인 수.
         Kaiser 기준이 기계적이라면 스크리는 눈으로 판단하는 보완 수단이다.

   [요인 수 판정 결과]
     3요인  wsituation   (5.48 / 1.58 / 1.25)
     2요인  wstat        (2.82 / 1.23)
            weng         (2.44 / 1.54)  <- alpha 0.732 였으나 별개 개념
            hazard_phy   (5.67 / 1.01)  <- 경계값, 스크리 확인 필요
            wtime_length (3.00 / 1.00)  <- 경계값, 스크리 확인 필요
            heal_prob    (2.62 / 1.28)
     1요인  who, emp_manaqual, emp_comp_ass, hazard_psy, wwa,
            sleep, imte, decla, hazard_erg(erg5제외), condim(4제외)

   [SAS 와 Python 의 역할 분담]
     항목-총점 상관은 PROC CORR ALPHA 출력에 이미 포함되므로
     SAS 에는 Python 의 2.3-3 에 해당하는 별도 단계가 없다.
     반대로 스크리 도표는 SAS 만 제공한다.
   ------------------------------------------------------------ */
  /* ------------------------------------------------------------
   2.3-4 보충 : 출력 표에서 놓치기 쉬운 지표

   [Final Communality Estimates - 공통성]
     해당 문항의 분산 중 추출된 요인들이 설명하는 비율.
     0.4 미만이면 고유분산이 커서 요인 구조에 잘 맞지 않는다.

     0.4 미만으로 확인된 문항
       wsituation6 (원할 때 휴식 가능) 0.392
       heal_prob4  (두통, 눈의 피로)    0.356
       heal_prob6  (전신 피로)          0.342
     세 문항 모두 Rotated Factor Pattern 에서 교차적재를 보였다.
     공통성과 교차적재가 같은 결론을 가리키므로 지수 구성에서 제외를 검토한다.

     교차적재라도 공통성이 높으면 성격이 다르다.
       hazard_phy5 (분진 흡입) 적재 0.538 / 0.618, 공통성 0.672
       요인에 안 맞는 것이 아니라 두 요인 모두와 관련된 문항이다.

     wtime_length5 (교대근무) 공통성 0.9996, 적재 0.99976
       제2요인을 단독 점유. 다른 문항과 공유 분산이 없으므로
       지수가 아니라 단독 변수로 사용한다.

   [Eigenvalues 표의 Difference 열 - 스크리 판독]
     인접 고유값의 차이. 낙차가 큰 지점 다음이 elbow 다.
       wsituation  3.899 -> 0.330 -> 0.505 -> 0.023  4번째부터 평탄, 3요인 지지
       hazard_phy  4.665 -> 0.351 -> 0.273           2,3번 낙차 유사, 경계 사례

   [Variance Explained by Each Factor - 회전 전후 비교]
     회전은 설명분산 총량을 바꾸지 않고 요인 간 배분만 바꾼다.
       wsituation 회전 전 5.475 / 1.576 / 1.246 (합 8.297)
                  회전 후 3.653 / 2.897 / 1.748 (합 8.297)
     합이 같은지 확인하면 회전이 정상 수행되었음을 검산할 수 있다.

   [Python 과의 차이 - Kaiser 정규화]
     ROTATE=VARIMAX 의 기본값은 NORM=KAISER 다.
     회전 전에 각 문항의 적재 벡터를 공통성으로 나눠 길이를 1로 맞추고
     회전 후 되돌린다. 공통성이 큰 문항이 회전 방향을 독점하는 것을 막는다.
     Python 구현에 이를 반영하지 않으면 적재량이 최대 0.02 어긋난다.
     (반영 후 최대 오차 0.0005 로 일치. 요인 수와 배정 결론은 동일)
   ------------------------------------------------------------ */
  
/* ============================================================
   2.4 1차 변수 선택
     Python 에서 규칙 기반으로 산출한 제거 목록을 적용하고,
     제거 근거가 되는 분포를 SAS 에서 재확인한다.
   ============================================================ */

/* ------------------------------------------------------------
   2.4-1 저분산 변수 확인
     한 값에 95% 이상 몰린 변수는 분산이 거의 없어
     단독 투입 시 검정력이 나오지 않는다.
     다만 파생변수 재료인 경우 합산 지수로 살릴 수 있으므로
     즉시 제거하지 않고 분포만 확인한다.
   ------------------------------------------------------------ */
proc freq data=work.kwcs;
    tables asb5 asb6 asb7 disc6 disc7 disc8 heal_prob8
         / nocum nopercent;
    title '저분산 변수 - 폭력/차별/우울 (파생변수 재료로 보존)';
run;

/* ------------------------------------------------------------
   2.4-2 조사 운영 변수 확인
     분석 목적과 무관하거나 값이 사실상 하나인 변수.
     emp_type 은 임금근로자만 남겼으므로 전원 3, 상수다.
   ------------------------------------------------------------ */
proc freq data=work.kwcs;
    tables emp_type estat country mode panel_survey / nocum;
    title '조사 운영 변수 - 상수 여부 확인';
run;

/* ------------------------------------------------------------
   2.4-3 결측률 확인
     nmiss 로 변수별 결측 건수를 뽑는다.
     30,012 의 50% 인 15,006 을 넘는 변수가 제거 후보다.
   ------------------------------------------------------------ */
proc means data=work.kwcs n nmiss maxdec=0;
    var heal_prob1_1 heal_prob2_1 heal_prob3_1 heal_prob4_1 heal_prob6_1
        emp_con_period_r woutside1 woutside2;
    title '결측률 50% 초과 변수';
run;
title;

/* ------------------------------------------------------------
   2.4-4 제거 적용
     Python 의 drop_final 61개를 그대로 옮겼다.
     두 도구는 자동 동기화되지 않으므로 목록 이관은 수작업이다.
     적용 후 변수 수가 189개인지 반드시 확인한다.
   ------------------------------------------------------------ */
data work.kwcs_sel;
    set work.kwcs;
    drop
        /* 조사 운영 / 상수 */
        emp_type estat country mode panel_survey target
        hh_num eli_num year
        /* 고용 특성 */
        emp_con_term emp_fptime emp_own_mgmt emp_stat_sp
        emp_wage emp_place emp_rep emp_boss_gender emp_tra2
        comp_size1 comp_emp job1 job_c1_r
        /* 소득 구성 */
        income_con income_pos2 income_pos3 income_pos4 income_pos5
        income_pos6 income_pos7 income_pos9
        /* 근로시간 */
        ctime wday_week wtime_con_r ptime_r wtime_arr1
        wtime_ftwork wtime_ftcomtool wcomback
        wtime_long_a wtime_night3 wtime_resilience
        emp_con_period_r
        /* 작업 방식 */
        useequip2 useequip3 winten1_1
        winten3_1 winten3_2 winten3_3 winten3_4 winten3_5
        skillmat ass_cust1 alter_task1 wteam1
        /* 조직 변화 */
        ch_tech ch_restruct
        /* 근무 장소 */
        wplace4 wpalce_ch
        /* 건강 / 업무 외 활동 */
        heal_abs1 woutside2 woutside5
    ;
run;

proc contents data=work.kwcs_sel varnum;
    title '1차 선택 후 - 변수 189개 확인';
run;
title;

/* ------------------------------------------------------------
   2.4-5 결측 50% 초과 변수의 보존 근거
     조건부 문항의 결측은 무응답이 아니라 '질문 대상이 아님' 이다.
     본문항과 후속문항의 교차표로 이를 확인한다.
   ------------------------------------------------------------ */
proc freq data=work.kwcs_sel;
    tables heal_prob1 * heal_prob1_1 / missing norow nocol nopercent;
    title '요통 유무(본문항) x 업무 관련성(후속문항)';
run;

proc freq data=work.kwcs_sel;
    tables heal_prob5 * heal_prob4_1 / missing norow nocol nopercent;
    title '불안감 유무 x 두통 업무관련성 - 대조군';
run;
title;

/* ============================================================
   2.4 1차 변수 선택 - 결과 정리
   ============================================================ */

/* ------------------------------------------------------------
   [작업 구조]
     변수 선택 규칙은 Python 에서 산출하고, SAS 는 그 목록을 적용한다.
     두 도구는 자동 동기화되지 않으므로 DROP 문 이관은 수작업이며,
     적용 후 변수 수(189개)를 대조하는 것이 검산 절차가 된다.

   [제거 후보 5종 신호 - 중복 포함 137건, 실제 후보 102개]
     상수/준상수  12   한 값에 99% 이상
     조사운영      8   분석 목적과 무관한 관리 변수
     결측 50%+     7   결측률 0.50 초과
     저분산 95%+  29   한 값에 95% 이상
     |rho| < 0.05 81   종속변수와 거의 무관

   [보존 목록 3종 - 신호가 있어도 되살림]
     A 설계정보    복합표본 분석에 필수
     B 파생변수 재료  개별 분산은 작아도 합산 시 유효
     C 이론적 통제변수 단변량 상관이 낮아도 통제 역할 수행

     최종: 후보 102개 중 41개 보존, 61개 제거 -> 250 -> 189개

   [PROC FREQ 로 확인한 저분산 변수의 실제 빈도]
     asb5 신체적 폭력      75명 / 29,923명
     asb6 성희롱          145명 / 29,845명
     asb7 왕따 괴롭힘       66명 / 29,914명
     disc6 종교 차별        77명 / 19,355명
     heal_prob8 우울함     726명 / 29,240명
     비율은 낮으나 실재하는 사례이므로 합산 지표로 전환해 보존한다.

   [PROC FREQ 로 확인한 조사 운영 변수의 상수성]
     emp_type      30,012 전원이 3    완전 상수 (임금근로자만 남긴 결과)
     estat         2 가 99.75%
     country       1 이 99.85%
     mode          1 이 98.72%
     분산이 없어 어떤 검정에도 기여하지 못하므로 제거한다.

   [PROC MEANS 로 확인한 결측 50% 초과 변수]
     heal_prob1_1  응답  7,935 / 결측 22,077
     heal_prob2_1  응답  9,007 / 결측 21,005
     heal_prob3_1  응답  4,775 / 결측 25,237
     heal_prob4_1  응답  4,449 / 결측 25,563
     heal_prob6_1  응답  5,794 / 결측 24,218
     emp_con_period_r 응답 4,665 / 결측 25,347   -> 제거
     woutside1     응답 15,561 / 결측 14,451
     woutside2     응답 13,135 / 결측 16,877     -> 제거

     heal_prob{i}_1 은 조건부 문항이다.
     본문항에서 '해당 증상 있음'으로 답한 사람에게만 묻는 구조이므로
     결측은 무응답이 아니라 질문 대상이 아니었음을 뜻한다.
     본문항과 결합하면 결측 없는 파생변수를 만들 수 있어 보존한다.

     PROC FREQ 로 교차 확인 시 missing 옵션이 필요하다.
     옵션이 없으면 결측 행이 표에서 제외되어 정작 확인하려는 구조가 보이지 않는다.
   ------------------------------------------------------------ */
 