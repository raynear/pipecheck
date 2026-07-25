#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
언어 파일 번역 도구

사용법:
  python translate.py              # 수정된 내용만 번역 (DeepL 기본)
  python translate.py --full       # 모든 키를 다시 번역 (기존 번역 유지하면서 덮어쓰기)
  python translate.py --reset      # 모든 번역 파일을 삭제하고 처음부터 번역

번역 서비스 옵션:
  --translator deepl      DeepL로 번역 (기본값)
  --translator chatgpt    ChatGPT로 번역

API 키 옵션:
  --deepl-key <key>       DeepL API 키를 직접 입력
  --openai-key <key>      OpenAI API 키를 직접 입력

언어 선택 옵션:
  --languages <langs>     특정 언어만 번역 (예: ko-KR 또는 ko-KR,ja-JP)
                          기본값: all (모든 언어)

기타 옵션:
  --full    모든 키를 다시 번역합니다 (기존 번역 무시)
  --reset   모든 번역 파일을 초기화하고 전체 번역을 수행합니다

환경 변수 (키를 직접 입력하지 않은 경우):
  DEEPL_API_KEY     DeepL API 키
  OPENAI_API_KEY    OpenAI API 키
"""

import json
import os
import requests
import openai
import re
import subprocess
import argparse
from dotenv import load_dotenv

# .env 파일 로드 (프로젝트 루트)
import os.path
env_file_paths = [
    '../.env',
    '.env',
]

env_loaded = False
for env_path in env_file_paths:
    if os.path.exists(env_path):
        load_dotenv(env_path)
        env_loaded = True
        print(f"환경변수 파일 로드됨: {env_path}")
        break

if not env_loaded:
    print("환경변수 파일을 찾을 수 없습니다. 다음 경로들을 확인했습니다:")
    for path in env_file_paths:
        print(f"  - {path}")
    print("API 키를 직접 입력하거나 환경변수를 직접 설정해주세요.")

# 환경변수 디버깅 정보
print("\n=== 환경변수 디버깅 정보 ===")
print(f"DEEPL_API_KEY 존재: {'예' if os.getenv('DEEPL_API_KEY') else '아니오'}")
print(f"OPENAI_API_KEY 존재: {'예' if os.getenv('OPENAI_API_KEY') else '아니오'}")
if os.getenv('OPENAI_API_KEY'):
    print(f"OPENAI_API_KEY 앞 15자: {os.getenv('OPENAI_API_KEY')[:15]}...")
print("=============================\n")

# 설정 부분
BASE_LANG_FILE = 'en-US.json'  # 기본 언어 파일명

# 번역하지 않을 키들을 지정
SKIP_TRANSLATION_KEYS = ['language_settings']

def parse_arguments():
    """명령행 인자를 파싱합니다."""
    parser = argparse.ArgumentParser(description='언어 파일 번역 도구')
    parser.add_argument('--full', action='store_true', 
                       help='모든 키를 다시 번역합니다 (기존 번역 무시)')
    parser.add_argument('--reset', action='store_true',
                       help='모든 번역 파일을 초기화하고 전체 번역을 수행합니다')
    parser.add_argument('--translator', choices=['deepl', 'chatgpt'], default='deepl',
                       help='번역 서비스 선택 (기본값: deepl)')
    parser.add_argument('--deepl-key', type=str,
                       help='DeepL API 키를 직접 입력 (환경변수 대신)')
    parser.add_argument('--openai-key', type=str,
                       help='OpenAI API 키를 직접 입력 (환경변수 대신)')
    parser.add_argument('--languages', type=str, default='all',
                       help='번역할 언어 선택 (예: ko-KR 또는 ko-KR,ja-JP). 기본값: all')
    return parser.parse_args()

def read_target_languages():
    """config/project.md 파일에서 target-language 섹션을 읽어옵니다."""
    with open('config/project.md', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # target-language 섹션 찾기
    match = re.search(r'# target-language\n(.*?)\n\n', content, re.DOTALL)
    if not match:
        raise Exception("config/project.md에서 target-language 섹션을 찾을 수 없습니다.")
    
    # 언어 코드 추출
    languages = []
    for line in match.group(1).split('\n'):
        if line.strip() and line.strip().startswith('- '):
            lang_code = line.strip('- ').strip()
            languages.append(f"{lang_code}.json")
    
    return languages

def generate_asset_list():
    base_root = 'assets/languages'
    os.makedirs(base_root, exist_ok=True)
    
    # config/project.md에서 지원 언어 목록 가져오기
    locale_files = read_target_languages()
    
    # locales.json 업데이트
    with open(os.path.join(base_root, 'locales.json'), 'w', encoding='utf-8') as f:
        json.dump({'locales': locale_files}, f, ensure_ascii=False, indent=2)
    
    # 기본 영어 파일이 없다면 생성
    base_file_path = os.path.join(base_root, BASE_LANG_FILE)
    if not os.path.exists(base_file_path):
        with open(base_file_path, 'w', encoding='utf-8') as f:
            json.dump({
                "app_name": "BoilerPlate",
                "welcome": "Welcome to BoilerPlate",
                # 기본적인 번역 키들 추가
            }, f, ensure_ascii=False, indent=2)
    
    # 각 언어 파일 생성
    for locale_file in locale_files:
        file_path = os.path.join(base_root, locale_file)
        if not os.path.exists(file_path):
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump({}, f, ensure_ascii=False, indent=2)
    
    # Info.plist 업데이트
    update_info_plist(locale_files)
    
    return locale_files

def update_info_plist(locale_files):
    info_plist_path = 'ios/Runner/Info.plist'
    if not os.path.exists(info_plist_path):
        return
    
    with open(info_plist_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 언어 코드 추출 (예: "en-US.json" -> "en")
    language_codes = list(set(
        file.split('.')[0].split('-')[0] 
        for file in locale_files
    ))
    
    # CFBundleLocalizations 배열 생성
    localizations_array = '\n'.join(
        f'\t\t<string>{code}</string>' 
        for code in language_codes
    )
    
    new_section = f'''<key>CFBundleLocalizations</key>
  <array>
{localizations_array}
  </array>'''
    
    # 기존 CFBundleLocalizations 섹션 찾아서 교체
    pattern = r'<key>CFBundleLocalizations</key>\s*<array>.*?</array>'
    if re.search(pattern, content, re.DOTALL):
        content = re.sub(pattern, new_section, content, flags=re.DOTALL)
    else:
        content = content.replace('</dict>', f'{new_section}\n</dict>')
    
    with open(info_plist_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f'Updated Info.plist with languages: {", ".join(language_codes)}')

def load_json(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        return json.load(f)

def save_json(file_path, data):
    sorted_data = dict(sorted(data.items()))
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(sorted_data, f, ensure_ascii=False, indent=2)

def translate_deepl(text, target_lang, api_key):
    """DeepL API를 사용하여 번역합니다."""
    url = 'https://api-free.deepl.com/v2/translate'
    params = {
        'auth_key': api_key,
        'text': text,
        'target_lang': target_lang.split('-')[0].upper()
    }
    response = requests.post(url, data=params)
    result = response.json()
    return result['translations'][0]['text']

def translate_chatgpt(text, target_lang, api_key):
    """ChatGPT API를 사용하여 번역합니다."""
    # 언어 코드를 실제 언어명으로 변환 (영어로)
    lang_map = {
        'ko': 'Korean',
        'ja': 'Japanese', 
        'zh': 'Chinese',
        'de': 'German',
        'fr': 'French',
        'ru': 'Russian',
        'pt': 'Portuguese',
        'es': 'Spanish',
        'it': 'Italian',
        'nl': 'Dutch'
    }
    
    lang_code = target_lang.split('-')[0].lower()
    target_language = lang_map.get(lang_code, target_lang)
    
    # 디버깅 정보 출력 (텍스트가 짧을 때만)
    if len(text) < 50:
        print(f"🔍 [번역] '{text}' → {target_lang} ({target_language})")
    
    headers = {
        'Authorization': f'Bearer {api_key}',
        'Content-Type': 'application/json'
    }
    
    system_prompt = f'You are a professional translator. You MUST translate the given text to {target_language} only. Do NOT translate to any other language. IMPORTANT: The target language is {target_language}, not Korean, not Chinese, not any other language. Only {target_language}. Do not translate the text inside curly braces (e.g., {{name}}, {{count}}). These represent dynamic variables and should remain exactly as they are. Only respond with the translated text in {target_language}, no explanations.'
    
    data = {
        'model': 'gpt-4o',
        'messages': [
            {
                'role': 'system',
                'content': system_prompt
            },
            {
                'role': 'user',
                'content': text
            }
        ],
        'max_tokens': 1000,
        'temperature': 0.3
    }
    
    # API 요청 내용 디버깅 (짧은 텍스트만)
    if len(text) < 50:
        print(f"🔍 [API 요청] System: '...to {target_language}...'")
        print(f"🔍 [API 요청] User: '{text}'")
    
    response = requests.post('https://api.openai.com/v1/chat/completions', 
                           headers=headers, json=data)
    
    if response.status_code != 200:
        raise Exception(f"OpenAI API 호출 실패: {response.status_code} - {response.text}")
    
    result = response.json()
    translated_text = result['choices'][0]['message']['content'].strip()
    
    # API 응답 디버깅 (짧은 텍스트만)
    if len(text) < 50:
        print(f"🔍 [API 응답] '{translated_text}'")
    
    return translated_text

def translate(text, target_lang, translator='deepl', api_key=None):
    """선택된 번역 서비스를 사용하여 번역합니다."""
    if translator == 'chatgpt':
        return translate_chatgpt(text, target_lang, api_key)
    else:
        return translate_deepl(text, target_lang, api_key)

def translate_value(value, target_lang, key='', translator='deepl', api_key=None):
    """값의 타입에 따라 적절한 번역을 수행합니다."""
    # 번역 제외 키인 경우 그대로 반환
    if key in SKIP_TRANSLATION_KEYS:
        return value
        
    if isinstance(value, str):
        return translate(value, target_lang, translator, api_key)
    elif isinstance(value, list):
        return [translate(item, target_lang, translator, api_key) if isinstance(item, str) else translate_value(item, target_lang, key, translator, api_key) for item in value]
    elif isinstance(value, dict):
        return translate_nested_dict(value, target_lang, translator, api_key)
    return value

def translate_nested_dict(data, target_lang, translator='deepl', api_key=None):
    """중첩된 딕셔너리 구조를 재귀적으로 번역합니다."""
    result = {}
    for key, value in data.items():
        result[key] = translate_value(value, target_lang, key, translator, api_key)
    return result

def get_modified_lines(file_path):
    """Git diff를 사용하여 수정된 라인의 내용을 가져옵니다."""
    try:
        # Git diff 명령어 실행
        diff_output = subprocess.check_output(
            ['git', 'diff', file_path],
            universal_newlines=True
        )
        
        modified_content = {}
        current_json_line = ""
        
        for line in diff_output.split('\n'):
            # 추가된 라인만 처리 (+로 시작하고 +++가 아닌 라인)
            if line.startswith('+') and not line.startswith('+++'):
                line = line[1:].strip()  # '+' 제거
                
                # JSON 라인 누적
                current_json_line += line
                
                # 완전한 JSON 라인인지 확인
                try:
                    # 마지막 쉼표 처리
                    if current_json_line.endswith(','):
                        current_json_line = current_json_line[:-1]
                    
                    # JSON 형식으로 파싱 시도
                    parsed_line = json.loads('{' + current_json_line + '}')
                    key, value = next(iter(parsed_line.items()))
                    modified_content[key] = value
                    current_json_line = ""  # 초기화
                except json.JSONDecodeError:
                    # 완전한 JSON이 아니면 계속 누적
                    continue
        
        return modified_content
        
    except subprocess.CalledProcessError:
        print("Git diff 실행 중 오류가 발생했습니다.")
        return {}

def batch_translate_deepl(texts, target_lang, api_key):
    """DeepL API를 사용하여 여러 텍스트를 한 번에 번역합니다."""
    url = 'https://api-free.deepl.com/v2/translate'
    params = {
        'auth_key': api_key,
        'text': texts,  # DeepL API는 자동으로 텍스트 배열을 처리합니다
        'target_lang': target_lang.split('-')[0].upper()
    }
    
    try:
        response = requests.post(url, data=params)
        
        # HTTP 응답 상태 확인
        if response.status_code != 200:
            print(f"DeepL API 오류 - 상태 코드: {response.status_code}")
            print(f"응답 내용: {response.text}")
            raise Exception(f"DeepL API 호출 실패: {response.status_code}")
        
        result = response.json()
        
        # API 응답 구조 확인 및 디버깅
        if 'translations' not in result:
            print(f"DeepL API 응답에 'translations' 키가 없습니다.")
            print(f"실제 응답: {result}")
            
            # 일반적인 DeepL API 에러 메시지 확인
            if 'message' in result:
                raise Exception(f"DeepL API 에러: {result['message']}")
            else:
                raise Exception(f"예상하지 못한 DeepL API 응답 형식: {result}")
        
        return [t['text'] for t in result['translations']]
        
    except requests.exceptions.RequestException as e:
        print(f"네트워크 요청 오류: {e}")
        raise
    except json.JSONDecodeError as e:
        print(f"JSON 파싱 오류: {e}")
        print(f"응답 텍스트: {response.text}")
        raise

def batch_translate_chatgpt(texts, target_lang, api_key):
    """ChatGPT API를 사용하여 여러 텍스트를 한 번에 번역합니다."""
    # 언어 코드를 실제 언어명으로 변환 (영어로)
    lang_map = {
        'ko': 'Korean',
        'ja': 'Japanese', 
        'zh': 'Chinese',
        'de': 'German',
        'fr': 'French',
        'ru': 'Russian',
        'pt': 'Portuguese',
        'es': 'Spanish',
        'it': 'Italian',
        'nl': 'Dutch',
        'ms': 'Malay'
    }
    
    lang_code = target_lang.split('-')[0].lower()
    target_language = lang_map.get(lang_code, target_lang)
    
    print(f"🔍 [배치번역] {len(texts)}개 텍스트 → {target_lang} ({target_language})")
    
    headers = {
        'Authorization': f'Bearer {api_key}',
        'Content-Type': 'application/json'
    }
    
    # 텍스트들을 하나의 요청으로 번역
    texts_combined = '\n---SEPARATOR---\n'.join(texts)
    
    data = {
        'model': 'gpt-4o',
        'messages': [
            {
                'role': 'system',
                'content': f'You are a professional translator. You MUST translate each text separated by "---SEPARATOR---" to {target_language} only. Do NOT translate to any other language. IMPORTANT: The target language is {target_language}, not Korean, not Chinese, not any other language. Only {target_language}. Keep the same separator in your response. Only respond with the translated texts separated by "---SEPARATOR---", no explanations. If something cannot be translated, output it exactly as provided in the input.'
            },
            {
                'role': 'user',
                'content': texts_combined
            }
        ],
        'max_tokens': 2000,
        'temperature': 0.3
    }
    
    try:
        response = requests.post('https://api.openai.com/v1/chat/completions', 
                               headers=headers, json=data)
        
        if response.status_code != 200:
            raise Exception(f"OpenAI API 호출 실패: {response.status_code} - {response.text}")
        
        result = response.json()
        translated_combined = result['choices'][0]['message']['content'].strip()
        
        # 번역된 텍스트들을 분리
        translated_texts = translated_combined.split('---SEPARATOR---')
        
        # 원본 텍스트 수와 번역된 텍스트 수가 맞지 않으면 개별 번역으로 폴백
        if len(translated_texts) != len(texts):
            print("배치 번역 결과 개수가 맞지 않아 개별 번역으로 진행합니다.")
            return [translate_chatgpt(text, target_lang, api_key) for text in texts]
        
        return [text.strip() for text in translated_texts]
        
    except Exception as e:
        print(f"배치 번역 실패, 개별 번역으로 진행합니다: {e}")
        # 개별 번역으로 폴백
        return [translate_chatgpt(text, target_lang, api_key) for text in texts]

def batch_translate(texts, target_lang, translator='deepl', api_key=None):
    """선택된 번역 서비스를 사용하여 배치 번역을 수행합니다."""
    if translator == 'chatgpt':
        return batch_translate_chatgpt(texts, target_lang, api_key)
    else:
        return batch_translate_deepl(texts, target_lang, api_key)

def collect_translatable_texts(data, key_path=''):
    """딕셔너리에서 번역이 필요한 모든 텍스트를 수집합니다."""
    texts = []
    text_locations = []  # (키 경로, 인덱스) 형태로 저장

    def process_value(value, current_path):
        if isinstance(value, str):
            texts.append(value)
            text_locations.append(current_path)
        elif isinstance(value, list):
            for i, item in enumerate(value):
                new_path = f"{current_path}[{i}]"
                process_value(item, new_path)
        elif isinstance(value, dict):
            for k, v in value.items():
                new_path = f"{current_path}.{k}" if current_path else k
                process_value(v, new_path)

    process_value(data, key_path)
    return texts, text_locations

def apply_translations(data, translations, locations):
    """번역된 텍스트를 원래 위치에 적용합니다."""
    result = {}
    
    # 번역 결과를 순차적으로 적용
    for translation, location in zip(translations, locations):
        try:
            # 위치 정보가 단순 키인 경우
            if '.' not in location and '[' not in location:
                result[location] = translation
                continue
                
            # 중첩된 구조인 경우
            parts = location.split('.')
            current_dict = result
            
            # 마지막 키를 제외한 모든 부분에 대해 딕셔너리 구조 생성
            for part in parts[:-1]:
                if part not in current_dict:
                    current_dict[part] = {}
                current_dict = current_dict[part]
            
            # 마지막 키에 번역 결과 저장
            current_dict[parts[-1]] = translation
            
        except Exception as e:
            print(f"Warning: Failed to apply translation for {location}: {str(e)}")
            continue
    
    # 원본 데이터와 병합
    if isinstance(data, dict):
        data.update(result)
        return data
    return result

def main():
    # 명령행 인자 파싱
    args = parse_arguments()
    
    # API 키 설정
    translator = args.translator
    api_key = None
    
    if translator == 'deepl':
        api_key = args.deepl_key or os.getenv('DEEPL_API_KEY')
        print(f"DeepL API 키 소스: {'직접입력' if args.deepl_key else '환경변수'}")
        print(f"DeepL API 키 존재: {'예' if api_key else '아니오'}")
        if api_key:
            print(f"DeepL API 키 앞 10자: {api_key[:10]}...")
        if not api_key:
            print("DeepL API 키가 필요합니다. --deepl-key 옵션을 사용하거나 DEEPL_API_KEY 환경변수를 설정하세요.")
            return
    elif translator == 'chatgpt':
        api_key = args.openai_key or os.getenv('OPENAI_API_KEY')
        print(f"OpenAI API 키 소스: {'직접입력' if args.openai_key else '환경변수'}")
        print(f"OpenAI API 키 존재: {'예' if api_key else '아니오'}")
        
        if api_key:
            # API 키 정리 (공백, 개행문자 제거)
            original_key = api_key
            api_key = api_key.strip().replace('\n', '').replace('\r', '').replace(' ', '')
            
            print(f"OpenAI API 키 원본 길이: {len(original_key)}")
            print(f"OpenAI API 키 정리 후 길이: {len(api_key)}")
            print(f"OpenAI API 키 앞 10자: {api_key[:10]}...")
            print(f"OpenAI API 키 뒤 10자: ...{api_key[-10:]}")
            
            # API 키 형식 검증
            if not api_key.startswith('sk-'):
                print("⚠️  경고: OpenAI API 키가 'sk-'로 시작하지 않습니다.")
            
            # 일반적인 OpenAI API 키 길이 확인 (대략 50-60자)
            if len(api_key) < 40 or len(api_key) > 200:
                print(f"⚠️  경고: OpenAI API 키 길이가 비정상적입니다. 길이: {len(api_key)}")
            
        if not api_key:
            print("OpenAI API 키가 필요합니다. --openai-key 옵션을 사용하거나 OPENAI_API_KEY 환경변수를 설정하세요.")
            return
    
    print(f"번역 서비스: {translator.upper()}")
    
    # API 키 테스트
    if translator == 'chatgpt':
        print("OpenAI API 키를 테스트하는 중...")
        try:
            # 테스트용 언어 설정 (사용자가 요청한 언어 사용)
            test_lang = args.languages if args.languages.lower() != 'all' else 'ja-JP'
            if ',' in test_lang:
                test_lang = test_lang.split(',')[0].strip()
            
            print(f"테스트 언어: {test_lang}")
            test_result = translate_chatgpt("Hello", test_lang, api_key)
            print(f"✅ API 키 테스트 성공: '{test_result}'")
        except Exception as e:
            print(f"❌ API 키 테스트 실패: {e}")
            return
    
    print("config/project.md에서 지원 언어 목록을 읽어오는 중...")
    locale_files = generate_asset_list()
    
    # 언어 필터링
    selected_languages = args.languages
    if selected_languages.lower() != 'all':
        # 쉼표로 구분된 언어 목록 파싱
        target_languages = [lang.strip() for lang in selected_languages.split(',')]
        target_language_files = [f"{lang}.json" for lang in target_languages]
        
        # 요청된 언어가 지원 언어 목록에 있는지 확인
        available_languages = [f for f in locale_files if f != BASE_LANG_FILE]
        filtered_files = []
        
        for target_file in target_language_files:
            if target_file in available_languages:
                filtered_files.append(target_file)
                print(f"✅ 선택된 언어: {target_file}")
            else:
                print(f"❌ 지원하지 않는 언어: {target_file}")
                print(f"   사용 가능한 언어: {', '.join([f.replace('.json', '') for f in available_languages])}")
        
        if not filtered_files:
            print("번역할 언어가 없습니다.")
            return
            
        target_files = filtered_files
        print(f"\n{len(target_files)}개 언어로 번역을 진행합니다: {', '.join([f.replace('.json', '') for f in target_files])}")
    else:
        target_files = [f for f in locale_files if f != BASE_LANG_FILE]
        print(f"모든 언어로 번역을 진행합니다: {', '.join([f.replace('.json', '') for f in target_files])}")
    
    base_root = 'assets/languages'
    base_file_path = os.path.join(base_root, BASE_LANG_FILE)
    base_data = load_json(base_file_path)

    # 전체 번역 모드 확인
    if args.full or args.reset:
        print("전체 번역 모드로 실행합니다...")
        modified_content = {}  # 빈 딕셔너리로 설정하여 모든 키를 번역하도록 함
        force_all_keys = True
    else:
        # 수정된 라인 가져오기
        modified_content = get_modified_lines(base_file_path)
        force_all_keys = False
        
        if not modified_content:
            print("수정된 내용이 없습니다.")
            print("전체 번역을 원하시면 --full 또는 --reset 옵션을 사용하세요.")
            return

        print("수정된 내용:", modified_content)

    for target_file in target_files:
        target_path = os.path.join(base_root, target_file)
        target_lang = os.path.splitext(target_file)[0]
        
        print(f"\n🔍 [디버깅] {target_file} 번역 시작:")
        print(f"   - target_file: {target_file}")
        print(f"   - target_lang: {target_lang}")
        
        # 언어 매핑 확인
        lang_code = target_lang.split('-')[0].lower()
        lang_map = {
            'ko': '한국어',
            'ja': '일본어', 
            'zh': '중국어',
            'de': '독일어',
            'fr': '프랑스어',
            'ru': '러시아어',
            'pt': '포르투갈어',
            'es': '스페인어',
            'it': '이탈리아어',
            'nl': '네덜란드어'
        }
        target_language = lang_map.get(lang_code, target_lang)
        print(f"   - lang_code: {lang_code}")
        print(f"   - target_language: {target_language}")
        
        # reset 옵션인 경우 기존 파일 삭제
        if args.reset and os.path.exists(target_path):
            os.remove(target_path)
            print(f'[{target_file}] 기존 파일을 삭제했습니다.')
        
        if os.path.exists(target_path):
            target_data = load_json(target_path)
        else:
            target_data = {}

        # 번역할 키들 수집
        keys_to_translate = {}
        for key, value in base_data.items():
            if key == 'language_settings':
                target_data[key] = base_data[key]
                continue
            
            # 전체 번역 모드이거나, 누락되거나 수정된 키들
            if force_all_keys or key not in target_data or key in modified_content:
                keys_to_translate[key] = base_data[key]

        if keys_to_translate:
            print(f'[{target_file}] {len(keys_to_translate)} 개의 키를 {translator.upper()}로 번역 중...')
            
            # 번역할 텍스트 수집
            all_texts, locations = collect_translatable_texts(keys_to_translate)
            
            # 배치로 번역 수행
            BATCH_SIZE = 50 if translator == 'deepl' else 20  # ChatGPT는 더 작은 배치 사이즈 사용
            translated_texts = []
            
            for i in range(0, len(all_texts), BATCH_SIZE):
                batch_texts = all_texts[i:i + BATCH_SIZE]
                batch_start = i + 1
                batch_end = min(i + BATCH_SIZE, len(all_texts))
                print(f'  번역 진행 중... ({batch_start}-{batch_end}/{len(all_texts)})')
                
                batch_translations = batch_translate(batch_texts, target_lang, translator, api_key)
                translated_texts.extend(batch_translations)
            
            # 번역된 텍스트 적용
            translated_data = apply_translations(keys_to_translate, translated_texts, locations)
            target_data.update(translated_data)
            
            print(f'[{target_file}] {len(keys_to_translate)} 개의 키 번역 완료')
        else:
            print(f'[{target_file}] 번역할 내용이 없습니다.')
            
        save_json(target_path, target_data)
        print(f'[{target_file}] 파일이 업데이트되었습니다.')

if __name__ == '__main__':
    main()
