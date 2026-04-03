import React from 'react'
import { HashRouter, Routes, Route, Navigate } from 'react-router-dom'

// AppLayout will be created in Task 4 — placeholder for now
function AppLayout({ children }) {
  return <div className="app-layout">{children}</div>
}

// Page placeholders — actual components created in Task 5
const TokensPage = () => <div>Page: Tokens</div>
const DashboardPage = () => <div>Page: Dashboard</div>
const AuditPage = () => <div>Page: Audit</div>
const AdminUsersPage = () => <div>Page: Admin Users</div>
const AdminAuditPage = () => <div>Page: Admin Audit</div>
const AdminConfigPage = () => <div>Page: Admin Config</div>

export default function App() {
  return (
    <HashRouter>
      <Routes>
        <Route path="/" element={<Navigate to="/tokens" replace />} />
        <Route
          path="/tokens"
          element={
            <AppLayout>
              <TokensPage />
            </AppLayout>
          }
        />
        <Route
          path="/dashboard"
          element={
            <AppLayout>
              <DashboardPage />
            </AppLayout>
          }
        />
        <Route
          path="/audit"
          element={
            <AppLayout>
              <AuditPage />
            </AppLayout>
          }
        />
        <Route
          path="/admin/users"
          element={
            <AppLayout>
              <AdminUsersPage />
            </AppLayout>
          }
        />
        <Route
          path="/admin/audit"
          element={
            <AppLayout>
              <AdminAuditPage />
            </AppLayout>
          }
        />
        <Route
          path="/admin/config"
          element={
            <AppLayout>
              <AdminConfigPage />
            </AppLayout>
          }
        />
      </Routes>
    </HashRouter>
  )
}
