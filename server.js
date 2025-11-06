// Root launcher for Render (and other hosts) that expect `server.js` at project root.
// This simply forwards to the real backend entry point.

try {
  // Use require so we get proper stack traces and module caching.
  require('./backend/server');
} catch (err) {
  // If load fails, print a helpful message and rethrow so process exits with non-zero code.
  console.error('Failed to start backend server from ./backend/server.js');
  console.error(err && (err.stack || err.message) || err);
  // Rethrow to keep behavior identical to a normal node crash.
  throw err;
}
