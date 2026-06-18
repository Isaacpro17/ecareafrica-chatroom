const jwt = require('jsonwebtoken');

/**
 * Validates the JWT on every protected route.
 * Attaches decoded payload to req.user.
 */
function authenticate(req, res, next) {
  const authHeader = req.headers['authorization'];
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      error: 'UNAUTHORIZED',
      message: 'Missing or malformed Authorization header.',
    });
  }

  const token = authHeader.slice(7);
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({
        error: 'UNAUTHORIZED',
        message: 'Token has expired. Please log in again.',
      });
    }
    return res.status(401).json({
      error: 'UNAUTHORIZED',
      message: 'Invalid token.',
    });
  }
}

/**
 * Restricts a route to specific roles.
 * @param {...string} roles - Allowed roles: 'parent', 'teacher', 'student'
 */
function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'UNAUTHORIZED' });
    }
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        error: 'FORBIDDEN',
        message: `This action requires one of: ${roles.join(', ')}.`,
      });
    }
    next();
  };
}

/**
 * Validates the internal service key for bridge-to-bridge calls.
 */
function requireServiceKey(req, res, next) {
  const key = req.headers['x-chat-service-key'];
  if (!key || key !== process.env.CHAT_SERVICE_KEY) {
    return res.status(403).json({
      error: 'FORBIDDEN',
      message: 'Invalid or missing service key.',
    });
  }
  next();
}

module.exports = { authenticate, requireRole, requireServiceKey };
