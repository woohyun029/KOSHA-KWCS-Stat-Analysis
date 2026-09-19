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
   2.4-5 결측 50% 초과 변수의 보존 근거 - 교차표 결과

   [heal_prob1 x heal_prob1_1]
                       결측     1(예)   2(아니오)   합계
     결측(.)             21        0         0        21
     1 요통 있음          32    5,260     2,675     7,967
     2 요통 없음      22,024        0         0    22,024
     합계             22,077    5,260     2,675    30,012

     요통이 없다고 답한 22,024명이 100% 후속 문항 결측이다.
     결측 22,077명의 구성
       22,024 (99.76%)  요통이 없어 질문 대상이 아님
           21 ( 0.10%)  본문항 자체가 결측
           32 ( 0.14%)  요통 있으나 후속 무응답
     즉 결측의 실체는 무응답이 아니라 '해당 없음' 이다.

   [대조 확인 : heal_prob5 x heal_prob4_1]
     불안감이 없는 29,007명 중 3,803명이 두통 문항에 응답했다.
     짝이 아닌 문항끼리는 결측이 대응하지 않으므로,
     앞의 100% 대응은 우연이 아니라 조사 설계에 의한 것이다.

   [PROC FREQ 사용 시 주의]
     missing 옵션이 없으면 결측 행이 표에서 제외된다.
     조건부 문항의 결측 구조를 확인하려면 반드시 붙여야 한다.

   [결론]
     heal_prob{i}_1 5개는 결측률 70~85% 이지만 보존한다.
     본문항과 결합하면 전원에게 값이 부여되는 파생변수를 만들 수 있다.
     (2.5 에서 수행)
   ------------------------------------------------------------ */
 
 /* ============================================================
   2.5 파생변수 생성
     지수(index) = 비슷한 개념을 묻는 문항들을 하나의 숫자로 합친 변수
     방식 : 평균. 결측이 있어도 응답한 문항만으로 계산 가능하다.
   ============================================================ */

/* ------------------------------------------------------------
   2.5-1 WHO-5 정신건강 지수

     원 문항 who1~who5 : 1 항상 그랬다 ~ 6 그런 적 없다
       숫자가 클수록 부정적이므로 역코딩한다.
       역코딩 공식 : 새 값 = (최소 + 최대) - 원래 = 7 - 원래

     [주의] SAS 의 변수 목록 축약 x1-x5 는
            숫자가 이름 맨 끝에 있을 때만 쓸 수 있다.
            who1_r 처럼 뒤에 _r 이 붙으면 뺄셈으로 해석되어 오류가 난다.
            따라서 여기서는 문항을 하나씩 나열한다.

     SAS 함수
       n(of ...)     결측이 아닌 값의 개수를 센다
       mean(of ...)  결측을 자동 제외하고 나머지의 평균을 낸다
                     (Python 의 mean(skipna=True) 와 동일)
   ------------------------------------------------------------ */
data work.kwcs_idx;
    set work.kwcs_sel;

    /* 역코딩 : 클수록 좋음으로 방향 통일 */
    who1_r = 7 - who1;
    who2_r = 7 - who2;
    who3_r = 7 - who3;
    who4_r = 7 - who4;
    who5_r = 7 - who5;

    /* 응답 문항 수가 3개 이상일 때만 지수 생성 */
    n_who = n(of who1_r who2_r who3_r who4_r who5_r);

    if n_who >= 3 then
        idx_wellbeing = mean(of who1_r who2_r who3_r who4_r who5_r);
    else
        idx_wellbeing = .;

    drop who1_r who2_r who3_r who4_r who5_r n_who;
run;

/* 검증 1 : 지수의 분포 */
proc means data=work.kwcs_idx n nmiss mean std min max maxdec=2;
    var idx_wellbeing;
    title 'WHO-5 지수 - 기본 통계 (이론 범위 1.00~6.00)';
run;

/* 검증 2, 3 : 원본 문항 및 종속변수와의 상관 */
proc corr data=work.kwcs_idx spearman nosimple;
    var who1-who5 satisfaction;
    with idx_wellbeing;
    title 'WHO-5 지수 - 원본 문항 및 종속변수와의 상관';
run;
title;

/* ------------------------------------------------------------
   2.5-1 WHO-5 지수 - 결과 정리

   [산출 결과 - Python 과 완전 일치]
     N 29,993 / 결측 19 / 평균 3.98 / 표준편차 1.05 / 범위 1.00~6.00
     이론 범위 안에 들어와 역코딩과 평균 계산이 정상임을 확인했다.

   [대표성 - 지수 vs 원본 문항 스피어만 상관]
     who1 -0.887  who2 -0.821  who3 -0.870  who4 -0.870  who5 -0.879
     모두 0.8 이상으로 특정 문항에 치우치지 않았다.
     부호가 음수인 것은 정상이다.
     지수는 역코딩되어 '클수록 좋음'이고 원본은 '클수록 나쁨'이므로
     방향이 반대인 것이 당연하다.

   [Python 과의 값 차이]
     Python 의 .corr() 은 기본값이 피어슨이고 여기서는 spearman 을 지정했다.
     피어슨은 값 자체를, 스피어만은 순위를 쓴다.
     순서형 응답은 선택지 간 간격이 동일하다고 볼 수 없으므로
     스피어만이 적절하며, Python 쪽에 method='spearman' 을 명시해 통일했다.

   [종속변수와의 상관]
     idx_wellbeing x satisfaction = -0.22244
     개별 문항 최고값(who1, 0.219)과 사실상 동일한 수준이다.

     2.3-2 PROC CORR ALPHA 출력에서 who1~who5 상호 상관이 0.635~0.776 이었다.
     문항들이 이미 거의 같은 것을 재고 있어(alpha 0.927)
     평균을 내도 새로 얻는 정보가 거의 없다.
     지수화의 성공 기준은 '상관 증가' 가 아니라 '상관 유지' 이며,
     실제 이점은 결측 감소, 변수 축소, 공선성 해소에 있다.

   [결측 개선]
     완전응답 기준 29,970명 (2.3-4 PROC FACTOR 로그)
     3개 이상 기준 29,993명
     평균 방식으로 23명을 추가 확보했다.

   [SAS 문법 주의]
     변수 목록 축약 x1-x5 는 숫자가 이름 맨 끝에 있을 때만 쓸 수 있다.
     who1_r 처럼 뒤에 _r 이 붙으면 뺄셈으로 해석되어 오류가 난다.
     파생변수 이름은 who_r1 처럼 숫자를 뒤에 두거나, 문항을 하나씩 나열한다.
   ------------------------------------------------------------ */
  
/* ------------------------------------------------------------
   2.5-2 지수화 효과 검증 : 공선성 해소

     다중공선성(multicollinearity)
       서로 비슷한 변수를 함께 넣으면 각 변수의 기여를 구분할 수 없어
       계수가 불안정해지는 현상.
     VIF (Variance Inflation Factor, 분산팽창지수)
       해당 변수를 나머지 변수들로 예측했을 때의 겹침 정도.
       1에 가까울수록 독립적. 통상 5 초과 주의, 10 초과 문제.

     PROC REG 의 vif 옵션으로 확인한다.
     종속변수는 형식상 satisfaction 을 쓰지만
     여기서 보려는 것은 회귀계수가 아니라 설명변수 간 VIF 다.
   ------------------------------------------------------------ */

/* (A) 개별 문항 5개 투입 */
proc reg data=work.kwcs_idx plots=none;
    model satisfaction = who1 who2 who3 who4 who5 / vif;
    title 'VIF (A) 개별 문항 5개 투입';
run;
quit;

/* (B) 지수 1개 + 다른 변수 투입 */
proc reg data=work.kwcs_idx plots=none;
    model satisfaction = idx_wellbeing wbalance age wtime_r / vif;
    title 'VIF (B) 지수 1개 투입';
run;
quit;
title;

/* ------------------------------------------------------------
   2.5-2 공선성 검증 - 결과 정리

   [VIF - Python 과 일치]
     A 개별 문항 5개   who1 3.57507  who2 2.56350  who3 3.16477
                       who4 2.97248  who5 2.90336
     B 지수 1개        idx_wellbeing 1.03988
                       wbalance 1.06201  age 1.12152  wtime_r 1.15098

     개별 문항은 2.6~3.6 으로 서로 겹치고, 지수는 1.04 로 거의 독립적이다.
     임계값 5 를 넘지는 않으나 방향은 분명하다.

   [PROC REG 가 VIF 외에 보여준 것 - Parameter Estimates]
     A 모델
       who1  +0.05764  t=11.68  p<.0001
       who2  +0.03301  t= 8.07  p<.0001
       who3  +0.02111  t= 4.73  p<.0001
       who4  +0.00852  t= 1.96  p=0.0503   경계
       who5  -0.00570  t=-1.35  p=0.1767   부호 역전, 유의하지 않음

     2.5-1 에서 who5 와 satisfaction 의 단변량 상관은 +0.179 였다.
     단독으로는 양의 관계인 변수가 함께 투입되자 음수가 되었다.
     이것이 다중공선성의 실제 피해다.
     문항들이 공통 부분을 먼저 차지하면 남은 변수에는 잔여분만 남는다.

   [표본 크기 차이 - R2 직접 비교 불가]
     A Number of Observations Used = 29,970 (결측 42)
     B Number of Observations Used = 28,829 (결측 1,183)
     wtime_r 의 결측으로 B 에서 1,183명이 제외되었다.
     R2 0.0526 vs 0.1147 의 차이를 지수화 효과로 해석할 수 없다.
     동일 표본 비교는 2.5-3 에서 수행한다.

   [PROC REG 문법 주의]
     대화형 프로시저이므로 run; 만으로 종료되지 않는다.
     반드시 quit; 을 붙여야 한다.
     model 문 앞에 라벨(예: A_items:)을 붙이면
     여러 모델을 한 번에 돌리고 출력에서 구분할 수 있다.
   ------------------------------------------------------------ */
  
/* ------------------------------------------------------------
   2.5-3 동일 표본에서 모델 비교

     앞의 PROC REG 에서 A 는 29,970명, B 는 28,829명을 사용했다.
     wtime_r 의 결측 때문에 표본이 달라 R2 를 직접 비교할 수 없다.
     두 모델에 필요한 변수가 모두 있는 관측치만 남겨 다시 비교한다.
   ------------------------------------------------------------ */
  
data work.cmp;
    set work.kwcs_idx;
    if nmiss(of satisfaction idx_wellbeing wbalance age wtime_r
                who1 who2 who3 who4 who5) = 0;
run;

proc reg data=work.cmp plots=none;
    A_items:    model satisfaction = who1 who2 who3 who4 who5;
    B_index:    model satisfaction = idx_wellbeing;
    C_items_x:  model satisfaction = who1 who2 who3 who4 who5
                                     wbalance age wtime_r / vif;
    D_index_x:  model satisfaction = idx_wellbeing wbalance age wtime_r / vif;
    title '동일 표본 기준 모델 비교';
run;
quit;
title;

/* ------------------------------------------------------------
   2.5-3 동일 표본 모델 비교 - 결과 정리

   [표본 통일]
     2.5-2 에서 A 29,970명 / B 28,829명으로 표본이 달라 비교가 불가능했다.
     nmiss() = 0 조건으로 필요한 변수가 모두 있는 28,809명만 남겨 재실행했다.
     네 모델 모두 Number of Observations Used = 28,809 로 동일하다.

   [R-Square 비교 - Python 과 소수점 넷째 자리까지 일치]
     A_items    변수 5개  R2 0.0498  Adj 0.0496
     B_index    변수 1개  R2 0.0468  Adj 0.0468
     C_items_x  변수 8개  R2 0.1172  Adj 0.1170
     D_index_x  변수 4개  R2 0.1146  Adj 0.1145

     R2 는 변수를 추가하기만 해도 상승하므로,
     변수 수가 다른 모델은 Adj R-Sq 로 비교한다.

   [지수화 비용]
     A -> B : 변수 5개를 1개로 줄이고 R2 손실 0.0030
     C -> D : 변수 8개를 4개로 줄이고 R2 손실 0.0026
     변수 4개를 절약하는 대가가 0.3%포인트 수준이다.

   [공선성 피해 - Parameter Estimates 비교]
     who4  A 모델 p=0.0279 (유의)  ->  C 모델 p=0.4252 (무의미)
     who5  A 모델 p=0.2708        ->  C 모델 p=0.4623
           두 모델 모두 계수가 음수. 단변량 상관은 +0.179 였다.
     변수를 많이 넣을수록 개별 문항이 자리를 잃는다.

     반면 D 모델의 idx_wellbeing
       계수 -0.09126  t=-31.85  p<.0001  VIF 1.03986
     지수는 다른 변수가 들어와도 안정적이다.

   [부수적 발견 - 04 모델링에서 재확인 필요]
     wtime_r (실제 주당 근무시간)  C p=0.3904 / D p=0.3706  유의하지 않음
     wbalance (근무시간의 생활 적합성) C t=45.48 / D t=45.56  최강 변수

     근무시간의 절대량보다 그 시간이 개인 생활과 맞물리는지가
     만족도를 좌우할 가능성이 있다.
     단, 현 단계는 가중치 미적용 단순 회귀다.
     PROC SURVEYLOGISTIC 으로 복합표본 설계를 반영해 재확인한다.
   ------------------------------------------------------------ */
  
/* ------------------------------------------------------------
   2.5-4 지수 생성 준비 : 블록별 척도 범위 확인

     역코딩 공식은 (최소 + 최대) - 원래값 이므로
     블록마다 척도 범위를 먼저 알아야 한다.
     PROC MEANS 의 min, max 로 실제 관측 범위를 확인한다.

     [주의] 관측 범위는 '데이터에 실제로 나타난 값' 이다.
            예를 들어 1~5 척도인데 아무도 5를 고르지 않았다면
            최대값이 4로 나온다. 최종 확인은 코드북으로 해야 한다.
   ------------------------------------------------------------ */
  
proc means data=work.kwcs_idx min max n nmiss maxdec=0;
    var emp_manaqual1-emp_manaqual5
        hazard_erg1 hazard_erg2 hazard_erg3 hazard_erg4 hazard_erg6
        hazard_psy1-hazard_psy3
        wwa1-wwa5  sleep1-sleep3  imte1-imte5;
    title '블록별 척도 범위 (1) - 상사자질 / 위험 / 일가정 / 수면 / 기술';
run;

proc means data=work.kwcs_idx min max n nmiss maxdec=0;
    var condim1 condim2 condim3 condim5 condim6
        decla1-decla3  wstat1-wstat7  weng1-weng5
        wtime_length1-wtime_length4;
    title '블록별 척도 범위 (2) - 작업특성 / 자율성 / 업무동의 / 열의 / 근무형태';
run;

proc means data=work.kwcs_idx min max n nmiss maxdec=0;
    var heal_prob1-heal_prob6 heal_prob8
        asb1-asb7
        disc1 disc5 disc6 disc7 disc8 disc9 disc10 disc11;
    title '블록별 척도 범위 (3) - 건강문제 / 폭력 / 차별';
run;
title;