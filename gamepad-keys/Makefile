BIN := .build/release/GamepadKeys
# Проміжна збірка — запускати не звідси, а тільки з /Applications.
# (Коментар мусить бути окремим рядком: make забирає у значення змінної
#  все до кінця рядка, разом із пробілами перед «#».)
APP := .build/GamepadKeys.app
ICONSET := .build/AppIcon.iconset
ICNS := .build/AppIcon.icns
INSTALLED := /Applications/GamepadKeys.app

CERT_NAME := GamepadKeys Local
# Якщо сертифікат створено (make cert) — підписуємо ним, інакше ad-hoc.
SIGN := $(shell security find-identity -v -p codesigning 2>/dev/null \
          | grep -q "$(CERT_NAME)" && echo "$(CERT_NAME)" || echo "-")

.PHONY: app install run cert icon clean

## Зібрати бандл у .build (сам по собі не для запуску)
app: icon
	swift build -c release
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp $(BIN) $(APP)/Contents/MacOS/GamepadKeys
	cp Info.plist $(APP)/Contents/Info.plist
	cp $(ICNS) $(APP)/Contents/Resources/AppIcon.icns
	codesign --force --deep --sign "$(SIGN)" $(APP)
	@test "$(SIGN)" = "-" && echo "увага: ad-hoc підпис — дозвіл «Універсальний доступ» доведеться видати наново (див. make cert)" || true

## Єдина копія для запуску живе в /Applications.
## Дозвіл TCC прив'язаний до шляху: дві копії в різних місцях — це для macOS
## дві різні програми, і дозвіл, виданий одній, для другої не діє.
install: app
	pkill -x GamepadKeys || true
	rm -rf $(INSTALLED)
	cp -R $(APP) $(INSTALLED)
	@echo "встановлено: $(INSTALLED)"

run: install
	open $(INSTALLED)

clean:
	rm -rf .build GamepadKeys.app

## Іконка малюється кодом (Tools/make-icon.swift), у репозиторії PNG не лежать.
icon: $(ICNS)

$(ICNS): Tools/make-icon.swift
	@swift Tools/make-icon.swift $(ICONSET)
	@iconutil -c icns $(ICONSET) -o $(ICNS)

## Одноразово: створити самопідписаний сертифікат для стабільного підпису.
## Ad-hoc підпис змінює хеш при кожній збірці, і macOS щоразу скидає дозвіл
## «Універсальний доступ». Постійний сертифікат цю тяганину прибирає назавжди.
## Запитає пароль від зв'язки ключів — це нормально.
cert:
	@openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
	  -keyout /tmp/gpk-key.pem -out /tmp/gpk-cert.pem \
	  -subj "/CN=$(CERT_NAME)" \
	  -addext "basicConstraints=critical,CA:false" \
	  -addext "keyUsage=critical,digitalSignature" \
	  -addext "extendedKeyUsage=critical,codeSigning" 2>/dev/null
	# Apple `security` не читає PKCS#12 у типовому для OpenSSL 3 форматі —
	# потрібні старі алгоритми. Пароль обов'язково непорожній: при порожньому
	# MAC рахується інакше і імпорт падає з «wrong password».
	@openssl pkcs12 -export -inkey /tmp/gpk-key.pem -in /tmp/gpk-cert.pem \
	  -out /tmp/gpk.p12 -passout pass:gamepadkeys \
	  -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1
	security import /tmp/gpk.p12 -k ~/Library/Keychains/login.keychain-db \
	  -P gamepadkeys -A -T /usr/bin/codesign
	security add-trusted-cert -r trustRoot -p codeSign \
	  -k ~/Library/Keychains/login.keychain-db /tmp/gpk-cert.pem
	@rm -f /tmp/gpk-key.pem /tmp/gpk-cert.pem /tmp/gpk.p12
	@echo "сертифікат «$(CERT_NAME)» створено — далі make install підписує ним"
