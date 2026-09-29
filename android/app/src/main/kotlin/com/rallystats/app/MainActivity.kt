package com.rallystats.app

import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import java.io.File
import java.security.KeyStore

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Antes de super.onCreate: ahí arranca el engine de Flutter, y con él
        // (desde Dart) Firebase Auth, que es quien usa estas preferencias.
        resetOrphanedFirebaseAuthKeyset()
        super.onCreate(savedInstanceState)
    }

    /**
     * Firebase Auth guarda la sesión cifrada, con un keyset (en
     * SharedPreferences) que a su vez está cifrado con una clave del Android
     * Keystore. El Auto Backup de Android respalda y restaura las
     * SharedPreferences, pero nunca las claves del Keystore: tras reinstalar
     * la app (o pasarla a otro equipo) queda un keyset restaurado cuya clave
     * ya no existe. Firebase no se recupera solo de eso — cada login falla al
     * cifrar la sesión ("KeysetManager failed to initialize - unable to
     * encrypt data" en logcat), así que la sesión sólo vive en memoria y se
     * pierde apenas se cierra la app desde recientes.
     *
     * Si encuentra ese estado (keyset cifrado presente, clave del Keystore
     * ausente), borra el keyset y la sesión guardada con él (de todos modos
     * irrecuperable), para que Firebase genere una clave nueva en el próximo
     * login. `backup_rules.xml`/`data_extraction_rules.xml` evitan que se
     * vuelvan a restaurar; esto repara las instalaciones que ya quedaron así.
     */
    private fun resetOrphanedFirebaseAuthKeyset() {
        try {
            val prefsDir = File(applicationInfo.dataDir, "shared_prefs")
            val keysetFiles = prefsDir.listFiles { file ->
                file.name.startsWith(CRYPTO_PREFS_PREFIX) && file.name.endsWith(".xml")
            } ?: return
            if (keysetFiles.isEmpty()) return
            val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
            for (file in keysetFiles) {
                val prefsName = file.name.removeSuffix(".xml")
                val persistenceKey = prefsName.removePrefix(CRYPTO_PREFS_PREFIX)
                if (keyStore.containsAlias(MASTER_KEY_ALIAS_PREFIX + persistenceKey)) continue
                val keysetPrefs = getSharedPreferences(prefsName, MODE_PRIVATE)
                // Tink guarda el keyset en hex. Uno cifrado con el Keystore es
                // un proto `EncryptedKeyset`, cuyo primer campo (#2) arranca en
                // "12"; uno en claro (lo que hace Tink si el Keystore del equipo
                // no funciona) arranca en "08" y sí es válido sin clave: ese no
                // se toca.
                val keyset = keysetPrefs.getString(KEYSET_PREF_NAME, null) ?: continue
                if (!keyset.startsWith("12")) continue
                Log.w(TAG, "Keyset de Firebase Auth sin su clave del Keystore (restaurado por backup): se regenera")
                keysetPrefs.edit().clear().commit()
                getSharedPreferences(STORE_PREFS_PREFIX + persistenceKey, MODE_PRIVATE)
                    .edit().clear().commit()
            }
        } catch (e: Exception) {
            // Defensivo: nunca impedir que la app arranque por esto.
            Log.w(TAG, "No se pudo revisar el keyset de Firebase Auth", e)
        }
    }

    private companion object {
        const val TAG = "RallyStats"
        const val CRYPTO_PREFS_PREFIX = "com.google.firebase.auth.api.crypto."
        const val STORE_PREFS_PREFIX = "com.google.firebase.auth.api.Store."
        const val MASTER_KEY_ALIAS_PREFIX = "firebear_main_key_id_for_storage_crypto."
        const val KEYSET_PREF_NAME = "StorageCryptoKeyset"
    }
}
