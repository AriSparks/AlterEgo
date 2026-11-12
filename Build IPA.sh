APP_PATH=$(find build/AlterEgo.xcarchive/Products/Applications -name "*.app" -maxdepth 1 | head -n 1)
IPA_NAME="AlterEgo.ipa"

mkdir -p build/ipa/Payload
cp -r "$APP_PATH" build/ipa/Payload/
cd build/ipa
zip -r "$IPA_NAME" Payload
