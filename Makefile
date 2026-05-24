.PHONY: serve clean

## 로컬 서버 실행 (캐시 없이)
serve:
	bundle exec jekyll serve --config _config.yml,_config_dev.yml

## 캐시 전체 삭제
clean:
	bundle exec jekyll clean
	rm -rf .sass-cache
