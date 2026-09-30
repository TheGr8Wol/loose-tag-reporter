import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { AppShell } from './shell/AppShell'
import { ThemeProvider } from './theme/ThemeProvider'
import './styles/tokens.css'

const queryClient = new QueryClient()

function Placeholder({ title }: { title: string }) {
  return (
    <div>
      <h1 style={{ marginTop: 0 }}>{title}</h1>
      <p style={{ color: 'var(--ink-2)', maxWidth: '65ch' }}>
        Scaffold only (WD0–WD2). Data screens land after auth (WD3) and typed views (WD5).
      </p>
    </div>
  )
}

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <ThemeProvider>
        <BrowserRouter>
          <Routes>
            <Route element={<AppShell role="lp_admin" />}>
              <Route index element={<Placeholder title="Overview" />} />
              <Route path="reports" element={<Placeholder title="Reports" />} />
              <Route path="heatmap" element={<Placeholder title="Heatmap" />} />
              <Route path="flag-settings" element={<Placeholder title="Flag settings" />} />
              <Route path="accounts" element={<Placeholder title="Accounts" />} />
              <Route path="*" element={<Navigate to="/" replace />} />
            </Route>
          </Routes>
        </BrowserRouter>
      </ThemeProvider>
    </QueryClientProvider>
  )
}
