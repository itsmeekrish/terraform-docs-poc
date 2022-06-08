enable-git-hooks:
	git config core.hooksPath .githooks
	chmod +x .githooks/pre-commit