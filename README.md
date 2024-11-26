# Image Chat
[[Dataset]](https://huggingface.co/datasets/tabtoyou/KoLLaVA-v1.5-Instruct-581k) [[Base Model]](https://huggingface.co/jjhsnail0822/danube-ko-1.8b-base) [[LLaVA Model]](https://huggingface.co/jjhsnail0822/llava-danube-ko-1.8b-instruct)

<p align="center">
    <a><img src="Images/Image Chat Logo.png" width="40%"></a> <br>
    Image Chat Logo </p>

## 소개

- On-Device size Korean Multi-modal sLLM
- 언제 어디서나 한국어로 초경량 멀티모달 AI를 경험하세요!
- 텍스트와 이미지를 분석하여 당신에게 적합한 결과를 제공합니다.
- 모바일 환경 내 이미지 파일 및 카메라 사용 가능
- Image Chat은 최신 LLaVA 기술과 CLIP 기반 멀티모달 접근 방식을 결합하여, 한국어 자연어 처리 및 이미지 인식 기능을 오프라인으로 제공합니다.

## 사용 가능한 모델
<p align="center">
    <a><img src="Images/Model Selection.png" width="40%"></a> <br>
    </p>

- [Model FP 16](https://huggingface.co/Hongik-Project-2024/mmproj-model-f16.gguf)
    - [llava-danube-ko-1.8b-instruct](https://huggingface.co/jjhsnail0822/llava-danube-ko-1.8b-instruct) Fp16 GGUF 모델로 변환
    - 3.75 GB
    - 8 GB RAM 기기에서 사용 가능 (iPhone 15 프로 이후 모델, iPad)

- [Model Q8](https://huggingface.co/Hongik-Project-2024/danube-ko-1.8B-base-Q8_0.gguf)
    - [llava-danube-ko-1.8b-instruct](https://huggingface.co/jjhsnail0822/llava-danube-ko-1.8b-instruct) Q8_0 GGUF 모델로 변환
    - 모바일 환경에 적합
    - 6 GB RAM 기기에서 사용 가능 (iPhone) 13 프로 이후 모델)
    
## 개발팀원
윤웅상(yws804@naver.com), 정진홍(https://github.com/jjhsnail0822)

## Related Projects

- [LLaVA - Large Language and Vision Assistant](https://llava-vl.github.io/)
- [LLaVA-NeXT](https://github.com/LLaVA-VL/LLaVA-NeXT)
- [llama.cpp](https://github.com/ggerganov/llama.cpp)
- [LLaVA ios - Run LLaVA vision model on your phone!](https://github.com/prashanthsadasivan/llava-ios)
- [jjhsnail0822/Graduation-Project-2024](https://github.com/jjhsnail0822/Graduation-Project-2024)
