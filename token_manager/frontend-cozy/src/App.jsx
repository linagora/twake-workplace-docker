import React from 'react'
import { HashRouter, Routes, Route, Navigate } from 'react-router-dom'
import AppLayout from './components/app-layout'
import TokensPage from './pages/TokensPage'
import DashboardPage from './pages/DashboardPage'
import AuditPage from './pages/AuditPage'
import AdminUsersPage from './pages/AdminUsersPage'
import AdminAuditPage from './pages/AdminAuditPage'
import AdminConfigPage from './pages/AdminConfigPage'

export default function App() {
  return (
    <HashRouter>
      <AppLayout>
        <Routes>
          <Route path="/" element={<Navigate to="/tokens" replace />} />
          <Route path="/tokens" element={<TokensPage />} />
          <Route path="/dashboard" element={<DashboardPage />} />
          <Route path="/audit" element={<AuditPage />} />
          <Route path="/admin/users" element={<AdminUsersPage />} />
          <Route path="/admin/audit" element={<AdminAuditPage />} />
          <Route path="/admin/config" element={<AdminConfigPage />} />
        </Routes>
      </AppLayout>
    </HashRouter>
  )
}
