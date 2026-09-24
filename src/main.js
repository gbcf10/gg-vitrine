import { createApp } from 'vue'
import App from './App.vue'
import router from './router'
import { initSession } from './lib/session'
import './styles.css'

initSession().then(() => {
  createApp(App).use(router).mount('#app')
})
