DART_DEFINE := --dart-define-from-file=dart_define.json

.PHONY: ios macos android web clean get devices

ios:
	flutter run -d iphone $(DART_DEFINE)

macos:
	flutter run -d macos $(DART_DEFINE)

android:
	flutter run -d android $(DART_DEFINE)

web:
	flutter run -d chrome $(DART_DEFINE)

# Pick a device interactively
run:
	flutter run $(DART_DEFINE)

devices:
	flutter devices

get:
	flutter pub get

clean:
	flutter clean && flutter pub get
