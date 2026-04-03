#!/usr/bin/env node

import { Command } from 'commander'
import Table from 'cli-table3'
import { TwakeTokenManager, ConsentRequiredError } from '../sdk/index.js'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface GlobalOpts {
  apiUrl: string
  token?: string
  tenant?: string
  format: string
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function getClient(opts: GlobalOpts): TwakeTokenManager {
  const oidcToken = opts.token ?? process.env.TWAKE_OIDC_TOKEN
  if (!oidcToken) {
    console.error('Error: OIDC token is required. Pass --token or set TWAKE_OIDC_TOKEN.')
    process.exit(1)
  }
  return new TwakeTokenManager({
    baseUrl: opts.apiUrl,
    oidcToken,
    tenant: opts.tenant,
  })
}

function output(data: unknown, format: string): void {
  if (format === 'json') {
    console.log(JSON.stringify(data, null, 2))
    return
  }

  // table format
  if (Array.isArray(data)) {
    if (data.length === 0) {
      console.log('(no results)')
      return
    }
    const headers = Object.keys(data[0] as object)
    const table = new Table({ head: headers })
    for (const row of data as Record<string, unknown>[]) {
      table.push(headers.map((h) => String(row[h] ?? '')))
    }
    console.log(table.toString())
  } else if (data !== null && data !== undefined && typeof data === 'object') {
    const table = new Table()
    for (const [key, value] of Object.entries(data as Record<string, unknown>)) {
      table.push({ [key]: String(value ?? '') })
    }
    console.log(table.toString())
  } else {
    console.log(data)
  }
}

// ---------------------------------------------------------------------------
// Program
// ---------------------------------------------------------------------------

const program = new Command()

program
  .name('twake-token-manager')
  .description('CLI for the Twake Token Manager API')
  .version('0.1.0')
  .option('--api-url <url>', 'Token Manager API base URL', 'https://token-manager-api.twake.local')
  .option('--token <oidc_token>', 'OIDC Bearer token')
  .option('--tenant <domain>', 'Tenant domain')
  .option('--format <format>', 'Output format: json or table', 'table')

// ---------------------------------------------------------------------------
// Token commands
// ---------------------------------------------------------------------------

program
  .command('create')
  .description('Create (or fetch) a service token')
  .requiredOption('--service <s>', 'Service name')
  .requiredOption('--user <u>', 'User identifier')
  .action(async (opts, cmd) => {
    const globals = cmd.parent.opts() as GlobalOpts
    const sdk = getClient(globals)
    try {
      const result = await sdk.getToken(opts.service, opts.user)
      output(result, globals.format)
    } catch (err) {
      if (err instanceof ConsentRequiredError) {
        console.error(`Consent required. Please visit:\n${err.redirectUrl}`)
        process.exit(2)
      }
      console.error('Error:', (err as Error).message)
      process.exit(1)
    }
  })

program
  .command('list')
  .description('List all tokens for a user')
  .requiredOption('--user <u>', 'User identifier')
  .action(async (opts, cmd) => {
    const globals = cmd.parent.opts() as GlobalOpts
    const sdk = getClient(globals)
    try {
      const result = await sdk.listTokens(opts.user)
      output(result, globals.format)
    } catch (err) {
      console.error('Error:', (err as Error).message)
      process.exit(1)
    }
  })

program
  .command('status')
  .description('Get the status of a service token')
  .requiredOption('--service <s>', 'Service name')
  .requiredOption('--user <u>', 'User identifier')
  .action(async (opts, cmd) => {
    const globals = cmd.parent.opts() as GlobalOpts
    const sdk = getClient(globals)
    try {
      const result = await sdk.getTokenStatus(opts.service, opts.user)
      output(result, globals.format)
    } catch (err) {
      console.error('Error:', (err as Error).message)
      process.exit(1)
    }
  })

program
  .command('refresh')
  .description('Refresh a service token')
  .requiredOption('--service <s>', 'Service name')
  .requiredOption('--user <u>', 'User identifier')
  .action(async (opts, cmd) => {
    const globals = cmd.parent.opts() as GlobalOpts
    const sdk = getClient(globals)
    try {
      const result = await sdk.refreshToken(opts.service, opts.user)
      output(result, globals.format)
    } catch (err) {
      console.error('Error:', (err as Error).message)
      process.exit(1)
    }
  })

program
  .command('revoke')
  .description('Revoke a service token (or all tokens) for a user')
  .option('--service <s>', 'Service name')
  .option('--all-services', 'Revoke all service tokens for the user')
  .requiredOption('--user <u>', 'User identifier')
  .action(async (opts, cmd) => {
    const globals = cmd.parent.opts() as GlobalOpts
    const sdk = getClient(globals)
    try {
      if (opts.allServices) {
        await sdk.revokeAllTokens(opts.user)
        console.log('All tokens revoked.')
      } else if (opts.service) {
        await sdk.revokeToken(opts.service, opts.user)
        console.log(`Token for service "${opts.service}" revoked.`)
      } else {
        console.error('Error: provide --service <s> or --all-services')
        process.exit(1)
      }
    } catch (err) {
      console.error('Error:', (err as Error).message)
      process.exit(1)
    }
  })

// ---------------------------------------------------------------------------
// Umbrella subcommand
// ---------------------------------------------------------------------------

const umbrella = program.command('umbrella').description('Manage umbrella tokens')

umbrella
  .command('create')
  .description('Create an umbrella token')
  .requiredOption('--user <u>', 'User identifier')
  .requiredOption('--scopes <s1,s2>', 'Comma-separated list of scopes')
  .action(async (opts, cmd) => {
    const globals = cmd.parent.parent.opts() as GlobalOpts
    const sdk = getClient(globals)
    try {
      const scopes = opts.scopes.split(',').map((s: string) => s.trim())
      const result = await sdk.getUmbrellaToken(opts.user, scopes)
      output(result, globals.format)
    } catch (err) {
      console.error('Error:', (err as Error).message)
      process.exit(1)
    }
  })

umbrella
  .command('introspect')
  .description('Introspect an umbrella token')
  .requiredOption('--token <twt_...>', 'Umbrella token to introspect')
  .action(async (opts, cmd) => {
    const globals = cmd.parent.parent.opts() as GlobalOpts
    const sdk = getClient(globals)
    try {
      const result = await sdk.introspectUmbrellaToken(opts.token)
      output(result, globals.format)
    } catch (err) {
      console.error('Error:', (err as Error).message)
      process.exit(1)
    }
  })

umbrella
  .command('revoke')
  .description('Revoke an umbrella token')
  .requiredOption('--token <twt_...>', 'Umbrella token to revoke')
  .action(async (opts, cmd) => {
    const globals = cmd.parent.parent.opts() as GlobalOpts
    const sdk = getClient(globals)
    try {
      await sdk.revokeUmbrellaToken(opts.token)
      console.log('Umbrella token revoked.')
    } catch (err) {
      console.error('Error:', (err as Error).message)
      process.exit(1)
    }
  })

// ---------------------------------------------------------------------------
// Admin subcommand
// ---------------------------------------------------------------------------

const admin = program.command('admin').description('Admin operations')

admin
  .command('list-tokens')
  .description('List all tokens for a tenant (admin)')
  .requiredOption('--tenant <domain>', 'Tenant domain')
  .action(async (opts, cmd) => {
    const globals = cmd.parent.parent.opts() as GlobalOpts
    const oidcToken = globals.token ?? process.env.TWAKE_OIDC_TOKEN
    if (!oidcToken) {
      console.error('Error: OIDC token is required. Pass --token or set TWAKE_OIDC_TOKEN.')
      process.exit(1)
    }
    try {
      const url = `${globals.apiUrl}/api/v1/admin/tokens?tenant=${encodeURIComponent(opts.tenant)}`
      const resp = await fetch(url, {
        headers: {
          Authorization: `Bearer ${oidcToken}`,
          'Content-Type': 'application/json',
        },
      })
      if (!resp.ok) {
        console.error(`Error: HTTP ${resp.status}`)
        process.exit(1)
      }
      const data = await resp.json()
      output(data, globals.format)
    } catch (err) {
      console.error('Error:', (err as Error).message)
      process.exit(1)
    }
  })

admin
  .command('audit')
  .description('Fetch admin audit log for a tenant')
  .requiredOption('--tenant <domain>', 'Tenant domain')
  .option('--user <u>', 'Filter by user identifier')
  .action(async (opts, cmd) => {
    const globals = cmd.parent.parent.opts() as GlobalOpts
    const oidcToken = globals.token ?? process.env.TWAKE_OIDC_TOKEN
    if (!oidcToken) {
      console.error('Error: OIDC token is required. Pass --token or set TWAKE_OIDC_TOKEN.')
      process.exit(1)
    }
    try {
      let url = `${globals.apiUrl}/api/v1/admin/audit?tenant=${encodeURIComponent(opts.tenant)}`
      if (opts.user) url += `&user=${encodeURIComponent(opts.user)}`
      const resp = await fetch(url, {
        headers: {
          Authorization: `Bearer ${oidcToken}`,
          'Content-Type': 'application/json',
        },
      })
      if (!resp.ok) {
        console.error(`Error: HTTP ${resp.status}`)
        process.exit(1)
      }
      const data = await resp.json()
      output(data, globals.format)
    } catch (err) {
      console.error('Error:', (err as Error).message)
      process.exit(1)
    }
  })

// ---------------------------------------------------------------------------
// Parse
// ---------------------------------------------------------------------------

program.parseAsync(process.argv)
