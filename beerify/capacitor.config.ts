import type { CapacitorConfig } from '@capacitor/cli'

const config: CapacitorConfig = {
  appId: 'app.beerify.mobile',
  appName: 'Beerify',
  webDir: 'dist',
  backgroundColor: '#10241c',
  ios: {
    contentInset: 'never',
    preferredContentMode: 'mobile',
  },
  plugins: {
    StatusBar: {
      style: 'LIGHT',
      overlaysWebView: true,
    },
    PushNotifications: {
      presentationOptions: [],
    },
  },
}

export default config
