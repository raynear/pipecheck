# 웹앱 랜딩페이지

앱 출시용 랜딩페이지와 Privacy Policy 템플릿입니다.

## 파일 구조

```
webapp/
├── index.html           # 메인 랜딩페이지
├── privacy-policy.html  # 개인정보처리방침
├── assets/              # 이미지 리소스 (직접 추가 필요)
│   ├── favicon.png
│   ├── apple-touch-icon.png
│   ├── og-image.png     # 소셜 미디어 공유용
│   ├── hero-mockup.png  # 히어로 섹션 목업
│   └── screenshot-*.png # 스크린샷들
└── README.md
```

## 사용 방법

### 1. 플레이스홀더 교체

HTML 파일의 `{{PLACEHOLDER}}` 부분을 실제 값으로 교체하세요:

| 플레이스홀더 | 설명 | 예시 |
|-------------|------|------|
| `{{APP_NAME}}` | 앱 이름 | SimpleTask |
| `{{APP_TAGLINE}}` | 앱 한 줄 소개 | 심플하게 할일 관리 |
| `{{APP_DESCRIPTION}}` | 앱 설명 (SEO용) | 가장 심플한 투두 앱... |
| `{{APP_KEYWORDS}}` | 키워드 (SEO용) | todo, 할일, task |
| `{{APP_URL}}` | 웹사이트 URL | https://myapp.com |
| `{{APP_STORE_URL}}` | App Store URL | https://apps.apple.com/... |
| `{{PLAY_STORE_URL}}` | Google Play URL | https://play.google.com/... |
| `{{DEVELOPER_NAME}}` | 개발자/회사명 | My Company |
| `{{SUPPORT_EMAIL}}` | 지원 이메일 | support@myapp.com |
| `{{YEAR}}` | 저작권 연도 | 2026 |
| `{{LAST_UPDATED}}` | 마지막 수정일 | 2026년 1월 12일 |
| `{{FEATURE_*_TITLE}}` | 기능 제목 | 원탭 할일 추가 |
| `{{FEATURE_*_DESC}}` | 기능 설명 | 한 번의 탭으로... |

### 2. 이미지 추가

`assets/` 폴더에 다음 이미지들을 추가하세요:

- **favicon.png**: 32x32 또는 16x16 파비콘
- **apple-touch-icon.png**: 180x180 Apple 터치 아이콘
- **og-image.png**: 1200x630 소셜 미디어 공유용
- **hero-mockup.png**: 히어로 섹션에 표시될 앱 목업
- **screenshot-1~4.png**: 앱 스크린샷

### 3. 배포

#### Vercel (무료)
```bash
npm i -g vercel
cd webapp
vercel
```

#### Netlify (무료)
```bash
# netlify.com에서 GitHub 연동 후 자동 배포
```

#### Firebase Hosting (권장)
```bash
# private repo는 GitHub Pages 무료 플랜 미지원 — 이 템플릿은 Firebase Hosting 사용
# (legal 페이지는 ./run deploy-legal이 같은 방식으로 배포)
firebase init hosting
firebase deploy
```

## 커스터마이징

### 색상 변경

`index.html`의 CSS 변수를 수정하세요:

```css
:root {
    --primary-color: #5B4CFF;   /* 메인 색상 */
    --primary-dark: #4338CA;    /* 메인 색상 (어두운) */
    --text-primary: #1F2937;    /* 텍스트 색상 */
    --text-secondary: #6B7280;  /* 보조 텍스트 */
}
```

### 섹션 추가/제거

HTML의 섹션(`<section>`)을 추가하거나 제거하세요.

### 다국어 지원

언어별로 별도 HTML 파일을 만들거나, JavaScript로 동적 전환 구현

## 체크리스트

- [ ] 모든 플레이스홀더 교체
- [ ] 이미지 추가 (favicon, og-image, mockup, screenshots)
- [ ] Privacy Policy 내용 검토
- [ ] 반응형 디자인 테스트 (모바일/태블릿/데스크탑)
- [ ] SEO 메타 태그 확인
- [ ] 배포 완료
- [ ] SSL 인증서 확인 (HTTPS)
