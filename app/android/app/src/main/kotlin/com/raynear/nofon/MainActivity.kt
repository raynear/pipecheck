package com.raynear.boilerplate

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.imagepicker.ImagePickerPlugin

class MainActivity: FlutterActivity()
//{
//
//    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
//        super.configureFlutterEngine(flutterEngine)
//
//        // ImagePicker 플러그인 설정
//        ImagePickerPlugin.registerWith(flutterEngine.plugins.registry)
//
//        // MethodChannel 설정
//        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.raynear.boilerplate/image_picker").setMethodCallHandler { call, result ->
//            if (call.method == "getLostData") {
//                getLostData(result)
//            } else {
//                result.notImplemented()
//            }
//        }
//    }
//
//    private fun getLostData(result: MethodChannel.Result) {
//        // 이 부분은 코루틴 스코프 내에서 실행되어야 합니다.
//        // 예를 들어 lifecycleScope.launch { ... } 내부에서 실행할 수 있습니다.
//        val picker = ImagePickerPlugin.getInstance()
//        val response = picker.retrieveLostImage()
//        if (response == null || response.isEmpty) {
//            result.success(null)
//            return
//        }
//        val files = response.files
//        if (files != null) {
//            handleLostFiles(files, result)
//        } else {
//            handleError(response.exception, result)
//        }
//    }
//
//    private fun handleLostFiles(files: List<Any>, result: MethodChannel.Result) {
//        // 복구된 파일 처리 로직
//        // 예: result.success(files.map { it.toString() })
//    }
//
//    private fun handleError(exception: Exception?, result: MethodChannel.Result) {
//        // 오류 처리 로직
//        result.error("LOST_DATA_ERROR", exception?.message, null)
//    }
//}
