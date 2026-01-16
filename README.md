# Bicep 및 Python SDK를 활용한 Azure AI Foundry

이 프로젝트는 **Bicep**을 사용하여 Azure AI Foundry 환경(구 Azure OpenAI Studio / Azure AI Studio)을 배포하고 **Python Azure AI Projects SDK**를 사용하여 상호 작용하는 방법을 보여줍니다.

배포되는 리소스:
- **Azure AI Hub** (`Microsoft.CognitiveServices/accounts`)
- **Azure AI Project** (`Microsoft.CognitiveServices/accounts/projects`)
- **모델 배포**: `gpt-4o-mini`
- **지원 리소스**: 스토리지 계정, Key Vault(선택/암시적), Application Insights, Log Analytics.

## 디렉토리 구조

```
├── infra/                  # Infrastructure as Code (Bicep)
│   ├── main.bicep          # Bicep 배포 진입점
│   ├── main.parameters.json
│   ├── core/               # 재사용 가능한 Bicep 모듈
│   │   ├── ai/             # AI 특정 리소스 (Hub, Project, Model)
│   │   ├── monitor/        # 로깅 및 모니터링
│   │   ├── storage/        # 스토리지 계정
│   └── ...
├── src/                    # 테스트용 소스 코드
│   └── chat_test.ipynb     # 배포된 에이전트/모델을 테스트하기 위한 Python 노트북
├── .gitignore              # Git 무시 규칙
└── README.md               # 이 파일
```

## 사전 요구 사항

- **Azure Developer CLI (`azd`)**: [`azd` 설치](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- **Python 3.10+**: [Python 설치](https://www.python.org/downloads/)
- **VS Code** 및 **Polyglot Notebooks** 또는 **Jupyter** 확장 프로그램.
- **PowerShell** (pwsh) 또는 적절한 터미널.

## 설정 및 배포

1.  **Azure 로그인**:
    ```pwsh
    azd auth login
    azd auth login --use-device-code
    ```

2.  **초기화 및 배포**:
    다음 명령을 실행하여 리소스를 프로비저닝하고 코드(인프라)를 배포합니다.
    ```pwsh
    azd up
    ```
    - 구독 및 위치를 선택하라는 메시지가 표시됩니다(예: `gpt-4o-mini`를 지원하는 `eastus2`, `swedencentral`, etc. - ensure the region supports `gpt-4o-mini`).
    - `azd`는 `infra/main.bicep`을 컴파일하고 리소스 그룹을 생성한 후 리소스를 배포합니다.

3.  **배포 확인**:
    - [Azure Portal](https://portal.azure.com)로 이동합니다.
    - `rg-{env_name}` 리소스 그룹을 찾습니다.
    - AI Hub, Project 및 모델 배포(`gpt-4o-mini`)가 생성되었는지 확인합니다.

## Python으로 테스트

1.  **Python 가상 환경 (venv) 구성**:
    프로젝트 루트에서 가상 환경을 생성하고 활성화합니다.
    ```pwsh
    # 가상 환경 생성
    cd src
    python -m venv .venv
    
    # 가상 환경 활성화 (Windows)
    .\.venv\Scripts\Activate.ps1
    
    # (선택 사항) 필요한 패키지 설치
    pip install azure-ai-projects azure-identity python-dotenv ipykernel
    ```

2.  **환경 변수**:
    배포 후 Python 스크립트에 필요한 환경 변수를 가져옵니다.
    ```pwsh
    azd env get-values > src/.env
    ```
    이 명령은 `src` 폴더에 `AZURE_AI_PROJECT_CONNECTION_STRING` 및 기타 값이 포함된 `.env` 파일을 생성합니다.

3.  **노트북 실행**:
    - VS Code에서 `src/chat_test.ipynb`를 엽니다.
    - **커널 선택 (Select Kernel)**을 클릭하고, 위에서 생성한 `.venv` (Python 환경)를 선택합니다.
    - 셀을 순차적으로 실행합니다.
    - 노트북은 다음 작업을 수행합니다:
        - **환경 설정**: 필요한 패키지 설치 (.env 설정).
        - **기본 채팅 (Chat Completion)**: `gpt-4o-mini` 모델과 직접 대화.
        - **기본 에이전트 (Basic Agent)**: 에이전트 생성, 스레드 관리, 기본 대화 실행.
        - **코드 인터프리터 (Code Interpreter)**: Python 코드를 실행하여 수학 계산 등 수행 (예: 피보나치 수열).
        - **함수 호출 (Function Calling)**: 사용자 정의 함수(Mock) 호출 및 결과 처리 (예: 날씨 정보 조회).
        - **파일 검색 (File Search / RAG)**: 문서 업로드 및 벡터 스토어 검색을 통한 답변 생성 (예: 제품 정보 검색).


## 실행 흐름

1.  **인프라 프로비저닝**: `main.bicep`은 AI Hub와 Project 생성을 오케스트레이션합니다. Project를 Hub에 연결하고 Hub 컨텍스트 내에 `gpt-4o-mini` 모델을 배포합니다.
2.  **클라이언트 연결**: Python 스크립트는 `DefaultAzureCredential`(로컬 CLI 로그인)과 Project 연결 문자열(Connection String)을 사용하여 인증합니다.
3.  **추론 (Inference)**: 스크립트는 모델에 프롬프트를 보내고 응답을 출력합니다.

## 정리 (Clean Up)

모든 리소스를 삭제하고 비용 발생을 방지하려면 다음을 실행하세요:

```pwsh
azd down
```
