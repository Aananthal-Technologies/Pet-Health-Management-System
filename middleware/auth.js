import jwt from 'jsonwebtoken';

export const verifyToken = (req, res, next) => {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, message: 'Unauthorized' });
  }
  try {
    req.user = jwt.verify(header.split(' ')[1], process.env.JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ success: false, message: 'Invalid or expired token' });
  }
};

export const verifyOwner = (req, res, next) => {
  verifyToken(req, res, () => {
    if (req.user.type !== 'owner') return res.status(403).json({ success: false, message: 'Forbidden' });
    next();
  });
};

export const verifyClinic = (req, res, next) => {
  verifyToken(req, res, () => {
    if (req.user.type !== 'clinic') return res.status(403).json({ success: false, message: 'Forbidden' });
    next();
  });
};
