# Sample Table Definitions

이 디렉토리는 Drift 테이블 정의 예제입니다.
새 테이블을 추가할 때 참고용으로 사용하세요.

## 포함된 예제

| 파일 | 설명 | 주요 패턴 |
|------|------|-----------|
| `post.dart` | 게시글 테이블 | Enum 필드, 인덱스, 기본값 |
| `comment.dart` | 댓글 테이블 | 자기 참조 (parentCommentId), Foreign Key |
| `tag.dart` | 태그 테이블 | 간단한 테이블, Unique 컬럼 |
| `post_tag.dart` | 게시글-태그 관계 | 다대다(M2M) 관계 테이블 |

## 사용 방법

1. 원하는 테이블 정의 파일을 `app/lib/data/definitions/`에 복사
2. `cd app && ./build.sh` 실행
3. 자동으로 생성됨:
   - `generated/drift/*.drift.dart` (Drift 테이블)
   - `generated/models/*.model.dart` (Freezed 모델)
   - `generated/repositories/*.repository.dart` (Repository)
4. `database.dart`에 테이블이 자동 등록됨

## 도메인 액션 예제

`domain/actions/post_actions.dart`는 게시글 생성/삭제/좋아요 등의
비즈니스 로직을 보여주는 예제입니다. Repository, Notification, Badge를
조합하는 패턴을 참고하세요.
