# APB3-Completer (검증용 slave RTL)

APB3 agent를 시험하기 위한 검증용 APB3 slave RTL과 self-checking 테스트벤치
사용언어: SystemVerilog (UVM 없음)
개발환경: Vivado xsim

이 모듈은 검증 대상이 아니라 **agent를 시험하기 위한 도구**임
로직을 단순하게 유지해 시험 중 불일치가 나오면 원인을 파형으로 가릴 수 있길 기대

## 특징

- APB3 기본 신호만 사용 (PSEL, PENABLE, PWRITE, PADDR, PWDATA, PRDATA, PREADY, PSLVERR)
- PREADY 동작을 모듈 파라미터로 선택
  - **ALWAYS_READY**: PREADY가 항상 1. 모든 전송이 setup 1 + access 1 = 2사이클
  - **RANDOM_DELAY**: access phase에서 전송마다0~3사이클 대기한 뒤 PREADY=1
    - 4-bit LFSR을 사용하여 최대 15 사이클로 늘릴 수 있음
- PSLVERR 응답은 에러 레지스터에 접근할 때 발생
- back-to-back 전송 지원

## 레지스터 맵

4 word, PADDR 4bit. PADDR[3:2]로 칸을 고르고 **하위 2비트는 무시**

| 주소 | 칸     | 동작                                                                                |
| ---- | ------ | ----------------------------------------------------------------------------------- |
| 0x0  | mem[0] | **에러**. 접근하면 항상 PSLVERR=1. write는 저장하지 않고, read는 PRDATA=0x05AD_D00D | <!--SAD DUDE임 ㄱㅇㅇ --> |
| 0x4  | mem[1] | 정상                                                                                |
| 0x8  | mem[2] | 정상                                                                                |
| 0xC  | mem[3] | 정상                                                                                |

- 리셋(PRESETn, active-low) 시 4칸 모두 0x01CE_B007 (ICE BOOT)
- 아직 쓰지 않은 정상 칸을 읽으면 0x01CE_B007, PSLVERR=0

## 응답 규칙

- PREADY, PRDATA, PSLVERR는 같은 resp_enable 신호를 받아 같은 타이밍에 나갑니다
- PRDATA와 PSLVERR는 PREADY=1인 사이클에서만 값이 나오고, 비access 구간과 대기 사이클에서는 0입니다
  - 이 게이팅은 APB3 스펙이 요구하는 규칙은 아니며, agent가 PREADY=1이 아닌 사이클에 샘플링하는 타이밍 버그를 scoreboard가 값 불일치로 검출하게 하려는 **시험용 규칙**입니다
- Requester는 PREADY=1인 posedge에서 PREADY, PRDATA, PSLVERR를 함께 샘플링합니다

자세한 포트 표, 블록도, 파형은 [`apb_completer_spec.md`](doc/apb_completer_spec.md)를 참고하세요.

## 디렉토리 구조

Makefile 기준 구조입니다 실제 폴더에 맞게 수정하세요.

```
.
├── rtl/        # slave RTL
├── tb/         # self-checking 테스트벤치
├── lib/        # 공용 헤더 (.svh)
├── doc/        # apb_completer_spec.md, 결과 로그 및 파형
└── Makefile
```

## 실행 방법

필요한 도구: Vivado xsim (xvlog, xelab, xsim). 파형 확인은 gtkwave.

```bash
make run MODE=ALWAYS     # ALWAYS_READY 모드로 컴파일 + 실행
make run MODE=RANDOM     # RANDOM_DELAY 모드로 컴파일 + 실행
make both                # 두 모드를 연달아 실행
make wave
make clean
```

- `MODE`는 `ALWAYS`, `RANDOM`만 허용하고, 다 값은 에러로 중단합니다
- 모드는 xelab의 `-generic_top`으로 elaborate 시점에 주입됩니다
- 로그는 `build/<top>_<MODE>.log`, PASS/FAIL 요약은 실행 끝에 출력됩니다

## 검증 내용

두 모드(ALWAYS_READY, RANDOM_DELAY)에서 각각 아래를 확인했습니다 TB는 기대값 배열을 따로 두고 모든 read를 자동으로 비교합니다

1. 리셋 직후 4칸 읽기 (초기값 확인)
2. 정상 칸과 에러 칸을 합쳐서, 한 칸에 쓰고 전체 칸을 읽는 동작을 전 구간에서 반복
   - 에러 칸의 PSLVERR와 PRDATA 확인
   - 주소 하위 2비트가 0이 아닌 접근 확인
3. back-to-back 전송 (IDLE 없이 연속)
4. 리셋-읽기 재실행

## 한계

- 랜덤 write/read 시나리오는 하지 않았습니다 4칸짜리 시험 도구라서 정해진 시나리오로 모든 칸을 확인했습니다
- PADDR 하위 2비트가 0이 아닌 접근은 RTL이 에러로 처리하지 않고 무시합니다 로그나 위반으로 등록하는 것은 SVA등이 필요합니다

## 결과

- 로그 결과
  [!로그](./doc/results/log_result_both.png)
- 모드 always/random에서 reset 후 레지스터 읽은 값 에러칸 제외 x01CE_B007
  - [!always](./doc/results/wave_always_reset.png)
  - [!random](./doc/results/wave_random_reset.png)
- 전체 쓰기 후 레지스터 읽은 값: 주소 값 <24 한 값으로 출력
  - [!always](./doc/results/wave_always_after_write.png)
  - [!random](./doc/results/wave_random_after_write.png)
- 다시 초기화 한 후 읽은 값: 에러 칸 제외x01CE_B007
  - [!always](./doc/results/wave_always_after_write.png)
  - [!random](./doc/results/wave_random_after_write.png)
