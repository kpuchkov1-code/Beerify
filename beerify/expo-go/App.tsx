import Constants from 'expo-constants';
import { StatusBar } from 'expo-status-bar';
import { useRef, useState } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, Text, View } from 'react-native';
import { WebView } from 'react-native-webview';

const metroHost = Constants.expoConfig?.hostUri?.split(':')[0];
const beerifyUrl = process.env.EXPO_PUBLIC_BEERIFY_URL
  ?? (metroHost ? `http://${metroHost}:5173` : 'https://beerify-lime.vercel.app');

export default function App() {
  const webView = useRef<WebView>(null);
  const [loading, setLoading] = useState(true);
  const [failed, setFailed] = useState(false);

  return (
    <View style={styles.container}>
      <StatusBar style="light" backgroundColor="#10241c" />
      <WebView
        ref={webView}
        source={{ uri: beerifyUrl }}
        style={styles.webview}
        sharedCookiesEnabled
        allowsBackForwardNavigationGestures
        onLoadStart={() => { setLoading(true); setFailed(false); }}
        onLoadEnd={() => setLoading(false)}
        onError={() => { setLoading(false); setFailed(true); }}
      />
      {loading && <View style={styles.overlay}><ActivityIndicator size="large" color="#f1ba3e" /><Text style={styles.loading}>Opening the pub…</Text></View>}
      {failed && (
        <View style={styles.overlay}>
          <Text style={styles.title}>Beerify couldn't reach the bar.</Text>
          <Text style={styles.copy}>Keep your phone and PC on the same Wi-Fi, then try again.{`\n\n`}{beerifyUrl}</Text>
          <Pressable style={styles.button} onPress={() => webView.current?.reload()}><Text style={styles.buttonText}>Try again</Text></Pressable>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#10241c' },
  webview: { flex: 1, backgroundColor: '#10241c' },
  overlay: { ...StyleSheet.absoluteFillObject, alignItems: 'center', justifyContent: 'center', gap: 14, backgroundColor: '#10241c', padding: 28 },
  loading: { color: '#f5f7f2', fontSize: 16, fontWeight: '700' },
  title: { color: '#f5f7f2', fontSize: 23, fontWeight: '900', textAlign: 'center' },
  copy: { color: '#bdcbbf', fontSize: 14, lineHeight: 20, textAlign: 'center' },
  button: { minHeight: 48, justifyContent: 'center', borderRadius: 10, backgroundColor: '#f1ba3e', paddingHorizontal: 24 },
  buttonText: { color: '#10241c', fontSize: 16, fontWeight: '800' },
});
