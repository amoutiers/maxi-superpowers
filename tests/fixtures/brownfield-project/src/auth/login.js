// Minimal auth module for the brownfield fixture.
export function hashPassword(pw) {
  return `hashed:${pw}`;
}

export function validateCredentials(user, pw) {
  return user && hashPassword(pw) === user.passwordHash;
}

export function issueSession(user) {
  return { token: `tok:${user.id}`, user };
}
