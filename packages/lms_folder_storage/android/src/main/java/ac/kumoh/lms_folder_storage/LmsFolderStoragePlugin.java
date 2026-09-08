package ac.kumoh.lms_folder_storage;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.provider.DocumentsContract;
import android.webkit.MimeTypeMap;
import java.io.*;
import java.util.*;
import java.util.concurrent.Executors;
import java.util.concurrent.ExecutorService;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

/** Registered as a Flutter plugin so WorkManager's headless engine can write too. */
public class LmsFolderStoragePlugin implements FlutterPlugin, ActivityAware,
        PluginRegistry.ActivityResultListener, MethodChannel.MethodCallHandler {
    private Context context;
    private ActivityPluginBinding binding;
    private MethodChannel channel;
    private MethodChannel.Result picker;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final ExecutorService io = Executors.newSingleThreadExecutor();
    private static final int PICK = 49312;
    @Override public void onAttachedToEngine(FlutterPluginBinding b) {
        context = b.getApplicationContext();
        channel = new MethodChannel(b.getBinaryMessenger(), "kumoh/folders");
        channel.setMethodCallHandler(this);
    }
    @Override public void onDetachedFromEngine(FlutterPluginBinding b) {
        channel.setMethodCallHandler(null);
        io.shutdown();
    }
    @Override public void onAttachedToActivity(ActivityPluginBinding b) {
        binding = b; b.addActivityResultListener(this);
    }
    @Override public void onDetachedFromActivityForConfigChanges() { detach(); }
    @Override public void onReattachedToActivityForConfigChanges(ActivityPluginBinding b) { onAttachedToActivity(b); }
    @Override public void onDetachedFromActivity() {
        detach();
        if (picker != null) { picker.success(null); picker = null; }
    }
    private void detach() {
        if (binding != null) binding.removeActivityResultListener(this);
        binding = null;
    }
    @Override public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        if (call.method.equals("pick")) {
            if (binding == null || picker != null) {
                result.error("picker_unavailable", "폴더 선택창을 열 수 없습니다.", null); return;
            }
            picker = result;
            Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION | Intent.FLAG_GRANT_PREFIX_URI_PERMISSION);
            try { binding.getActivity().startActivityForResult(intent, PICK); }
            catch (Exception e) { picker = null; result.error("picker_unavailable", "폴더 선택창을 열 수 없습니다.", null); }
            return;
        }
        io.execute(() -> {
            try {
                Object value;
                switch (call.method) {
                    case "validate": value = folder(call.argument("tree")).toString(); break;
                    case "exists": value = exists(Uri.parse(call.argument("uri"))); break;
                    case "save": value = save(call); break;
                    default: main.post(result::notImplemented); return;
                }
                main.post(() -> result.success(value));
            } catch (SecurityException e) {
                main.post(() -> result.error("folder_permission", "저장 폴더를 다시 선택해 주세요.", null));
            } catch (Exception e) {
                main.post(() -> result.error("folder_io", "폴더 또는 파일을 저장하지 못했습니다. 저장 공간과 폴더를 확인해 주세요.", null));
            }
        });
    }
    @Override public boolean onActivityResult(int request, int response, Intent data) {
        if (request != PICK || picker == null) return false;
        MethodChannel.Result result = picker; picker = null;
        if (response != Activity.RESULT_OK || data == null || data.getData() == null) {
            result.success(null); return true;
        }
        Uri uri = data.getData();
        try {
            int flags = data.getFlags() & (Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
            if ((flags & Intent.FLAG_GRANT_WRITE_URI_PERMISSION) == 0) throw new SecurityException();
            context.getContentResolver().takePersistableUriPermission(uri, flags);
            Map<String, String> value = new HashMap<>();
            value.put("uri", uri.toString());
            value.put("name", DocumentsContract.getTreeDocumentId(uri));
            result.success(value);
        } catch (Exception e) { result.error("folder_permission", "쓰기 가능한 폴더를 선택해 주세요.", null); }
        return true;
    }
    private Uri folder(String raw) throws Exception {
        Uri tree = Uri.parse(raw);
        boolean granted = context.getContentResolver().getPersistedUriPermissions().stream()
            .anyMatch(p -> p.getUri().equals(tree) && p.isReadPermission() && p.isWritePermission());
        if (!granted) throw new SecurityException();
        Uri root = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree));
        if (!exists(root)) throw new SecurityException();
        return root;
    }
    private boolean exists(Uri doc) {
        try (Cursor c = context.getContentResolver().query(doc,
                new String[]{DocumentsContract.Document.COLUMN_DOCUMENT_ID}, null, null, null)) {
            return c != null && c.moveToFirst();
        }
    }
    private void safe(String name) {
        if (name == null || name.isEmpty() || name.equals(".") || name.equals("..")
                || name.contains("/") || name.contains("\\") || name.indexOf('\0') >= 0)
            throw new IllegalArgumentException();
    }
    private Uri child(Uri parent, String name, boolean directory) throws Exception {
        Uri children = DocumentsContract.buildChildDocumentsUriUsingTree(parent, DocumentsContract.getDocumentId(parent));
        try (Cursor c = context.getContentResolver().query(children, new String[]{
                DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE}, null, null, null)) {
            while (c != null && c.moveToNext()) {
                if (name.equals(c.getString(1))) {
                    if (directory && !DocumentsContract.Document.MIME_TYPE_DIR.equals(c.getString(2))) throw new IOException();
                    return DocumentsContract.buildDocumentUriUsingTree(parent, c.getString(0));
                }
            }
        }
        return null;
    }
    private String save(MethodCall call) throws Exception {
        Uri root = folder(call.argument("tree"));
        String course = call.argument("course"); safe(course);
        String name = call.argument("name"); safe(name);
        File source = new File((String) call.argument("path")).getCanonicalFile();
        String cache = context.getCacheDir().getCanonicalPath() + File.separator;
        if (!source.getPath().startsWith(cache) || !source.isFile() || source.length() == 0) throw new IOException();
        Uri dir = child(root, course, true);
        if (dir == null) dir = DocumentsContract.createDocument(context.getContentResolver(), root,
                DocumentsContract.Document.MIME_TYPE_DIR, course);
        if (dir == null) throw new IOException();
        String finalName = name;
        // Never overwrite an existing user file, even if its name happens to match.
        for (int i = 2; child(dir, finalName, false) != null; i++) {
            int dot = name.lastIndexOf('.');
            finalName = dot > 0 ? name.substring(0, dot) + " (" + i + ")" + name.substring(dot)
                : name + " (" + i + ")";
        }
        int extAt = name.lastIndexOf('.');
        String mime = extAt < 0 ? null : MimeTypeMap.getSingleton()
                .getMimeTypeFromExtension(name.substring(extAt + 1).toLowerCase(Locale.ROOT));
        Uri temp = DocumentsContract.createDocument(context.getContentResolver(), dir,
                mime == null ? "application/octet-stream" : mime, ".lms-" + UUID.randomUUID() + ".part");
        if (temp == null) throw new IOException();
        try {
            try (InputStream in = new FileInputStream(source);
                 OutputStream out = context.getContentResolver().openOutputStream(temp, "w")) {
                if (out == null) throw new IOException();
                byte[] bytes = new byte[65536]; int n;
                while ((n = in.read(bytes)) != -1) out.write(bytes, 0, n);
                out.flush();
            }
            Uri complete = DocumentsContract.renameDocument(context.getContentResolver(), temp, finalName);
            if (complete == null) throw new IOException();
            return complete.toString();
        } catch (Exception e) {
            try { DocumentsContract.deleteDocument(context.getContentResolver(), temp); } catch (Exception ignored) {}
            throw e;
        }
    }
}
