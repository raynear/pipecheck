# release_notes/ — "이번 릴리스 What's New" SSOT

배포 자동화(`fastlane` release stage)가 **각 언어의 최신 릴리스 노트**를 여기서 읽어
스토어 메타데이터로 복사합니다. 스토어에 올라가는 "새로운 기능" 문구의 단일 출처입니다.

## 경로 계약

```
release_notes/
└── <lang>/                       # 언어 코드 (locale의 앞부분 — ko-KR → ko)
    └── release_notes_latest.md   # ← 배포가 읽는 파일 (이름 고정)
```

- `<lang>`은 `metadata/{ios,android}/<locale>` 폴더의 로케일에서 `-` 앞부분만 딴 값입니다
  (`en-US`→`en`, `ko-KR`→`ko`). release.rb가 `lang.split('-')[0]`로 매칭합니다.
- 파일명은 반드시 `release_notes_latest.md` 입니다.

## 배포 시 복사 경로 (fastlane/fastfiles/stage/release.rb)

| 플랫폼 | 대상 파일 | 비고 |
|--------|-----------|------|
| iOS | `metadata/ios/<locale>/release_notes.txt` | 전체 복사 |
| Android | `metadata/android/<locale>/changelogs/default.txt` | 앞 500자만 (Play 제한) |

- `release_notes_latest.md`가 **없으면** 해당 로케일의 기존 노트를 그대로 유지합니다 (soft-skip).
- 스토어 릴리스 노트는 **plain text**입니다 — 마크다운 서식(`#`, `**` 등)은 렌더링되지 않으니
  불릿(`- `)과 줄바꿈 정도만 쓰세요. 파일 내용이 **그대로** 스토어에 노출됩니다.

## 새 언어 추가

1. `metadata/ios/<locale>/` 와 `metadata/android/<locale>/` 폴더를 만든다 (배포 언어는 폴더 존재가 결정).
2. `release_notes/<lang>/release_notes_latest.md` 를 만든다.
