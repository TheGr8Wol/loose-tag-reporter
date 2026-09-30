import { NavLink, Outlet } from 'react-router-dom'
import { useTheme } from '../theme/ThemeProvider'
import './AppShell.css'

const nav = [
  { to: '/', label: 'Overview', end: true },
  { to: '/reports', label: 'Reports' },
  { to: '/heatmap', label: 'Heatmap' },
  { to: '/flag-settings', label: 'Flag settings', adminOnly: true },
  { to: '/accounts', label: 'Accounts', adminOnly: true },
]

export function AppShell({ role = 'supervisor' as 'supervisor' | 'lp_admin' }) {
  const { theme, toggle } = useTheme()
  const items = nav.filter((item) => !item.adminOnly || role === 'lp_admin')

  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">
          <span className="mark" aria-hidden="true">LT</span>
          <div>
            <strong>Loose Tag</strong>
            <div className="muted">LP Dashboard</div>
          </div>
        </div>
        <nav>
          {items.map((item) => (
            <NavLink key={item.to} to={item.to} end={item.end} className={({ isActive }) => (isActive ? 'nav active' : 'nav')}>
              {item.label}
            </NavLink>
          ))}
        </nav>
        <button type="button" className="theme-toggle" onClick={toggle}>
          {theme === 'light' ? 'Dark' : 'Light'} mode
        </button>
      </aside>
      <main className="content">
        <Outlet />
      </main>
    </div>
  )
}
