/// Neon backend endpoints for emergency-contact pairing (plan 009 Phase B).
///
/// Security model: the Data API only accepts anonymous JWTs minted from
/// [authTokenUrl]; the `anonymous` Postgres role can execute exactly three
/// pairing RPCs and touch nothing else (see backend/neon/001_invites.sql).
/// Nothing here is secret — these URLs ship in the app by design.
class BackendConfig {
  const BackendConfig._();

  static const String dataApiUrl =
      'https://ep-dry-pine-azhkfkqq.apirest.c-3.ap-southeast-1.aws.neon.tech/neondb/rest/v1';

  static const String authTokenUrl =
      'https://ep-dry-pine-azhkfkqq.neonauth.c-3.ap-southeast-1.aws.neon.tech/neondb/auth/token/anonymous';
}
