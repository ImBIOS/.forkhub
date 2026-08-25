# Sibling: fix-auth-stop-accumulating-authorized-client-sessi-p5zy3k6c

**Title**: fix(auth): stop accumulating authorized-client sessions per relaunch

**Status**: applied

**Reference diff**:

```diff
diff --git a/apps/desktop/src/backend/DesktopLocalEnvironmentAuth.test.ts b/apps/desktop/src/backend/DesktopLocalEnvironmentAuth.test.ts
index e7a58baef..2c1cd66f6 100644
--- a/apps/desktop/src/backend/DesktopLocalEnvironmentAuth.test.ts
+++ b/apps/desktop/src/backend/DesktopLocalEnvironmentAuth.test.ts
@@ -1,12 +1,17 @@
+import * as NodeServices from "@effect/platform-node/NodeServices";
 import { assert, describe, it } from "@effect/vitest";
 import * as Effect from "effect/Effect";
+import * as FileSystem from "effect/FileSystem";
 import * as Layer from "effect/Layer";
 import * as Option from "effect/Option";
+import * as Path from "effect/Path";
 import * as Ref from "effect/Ref";
 import * as HttpClient from "effect/unstable/http/HttpClient";
 import * as HttpClientResponse from "effect/unstable/http/HttpClientResponse";
 import { PRIMARY_LOCAL_ENVIRONMENT_ID } from "@t3tools/contracts";
 
+import * as DesktopConfig from "../app/DesktopConfig.ts";
+import * as DesktopEnvironment from "../app/DesktopEnvironment.ts";
 import * as DesktopBackendPool from "./DesktopBackendPool.ts";
 import * as DesktopLocalEnvironmentAuth from "./DesktopLocalEnvironmentAuth.ts";
 
@@ -29,53 +34,95 @@ const config = {
   captureOutput: true,
 };
 
-describe("DesktopLocalEnvironmentAuth", () => {
-  it.effect("exchanges the desktop bootstrap credential only once", () =>
-    Effect.gen(function* () {
-      const requestCount = yield* Ref.make(0);
-      const httpClientLayer = Layer.succeed(
-        HttpClient.HttpClient,
-        HttpClient.make((request) =>
-          Ref.update(requestCount, (count) => count + 1).pipe(
-            Effect.as(
-              HttpClientResponse.fromWeb(
-                request,
-                new Response(
-                  JSON.stringify({
-                    access_token: "desktop-bearer-token",
-                    issued_token_type: "urn:ietf:params:oauth:token-type:access_token",
-                    token_type: "Bearer",
-                    expires_in: 3600,
-                    scope: "orchestration:read",
-                  }),
-                  { status: 200, headers: { "content-type": "application/json" } },
-                ),
-              ),
+function makeLayer(baseDir: string, requestCount: Ref.Ref<number>) {
+  const httpClientLayer = Layer.succeed(
+    HttpClient.HttpClient,
+    HttpClient.make((request) =>
+      Ref.update(requestCount, (count) => count + 1).pipe(
+        Effect.as(
+          HttpClientResponse.fromWeb(
+            request,
+            new Response(
+              JSON.stringify({
+                access_token: "desktop-bearer-token",
+                issued_token_type: "urn:ietf:params:oauth:token-type:access_token",
+                token_type: "Bearer",
+                expires_in: 3600,
+                scope: "orchestration:read",
+              }),
+              { status: 200, headers: { "content-type": "application/json" } },
             ),
           ),
         ),
-      );
-      const poolLayer = Layer.succeed(DesktopBackendPool.DesktopBackendPool, {
-        list: Effect.succeed([
-          {
-            id: PRIMARY_LOCAL_ENVIRONMENT_ID,
-            label: Effect.succeed("Windows"),
-            currentConfig: Effect.succeed(Option.some(config)),
-          },
-        ]),
-      } as unknown as DesktopBackendPool.DesktopBackendPool["Service"]);
-      const testLayer = DesktopLocalEnvironmentAuth.layer.pipe(
-        Layer.provide(Layer.mergeAll(poolLayer, httpClientLayer)),
-      );
+      ),
+    ),
+  );
+
+  const poolLayer = Layer.succeed(DesktopBackendPool.DesktopBackendPool, {
+    list: Effect.succeed([
+      {
+        id: PRIMARY_LOCAL_ENVIRONMENT_ID,
+        label: Effect.succeed("Windows"),
+        currentConfig: Effect.succeed(Option.some(config)),
+      },
+    ]),
+  } as unknown as DesktopBackendPool.DesktopBackendPool["Service"]);
+
+  const environmentLayer = DesktopEnvironment.layer({
+    dirname: "/repo/apps/desktop/src",
+    homeDirectory: baseDir,
+    platform: "darwin",
+    processArch: "x64",
+    appVersion: "1.2.3",
+    appPath: "/repo",
+    isPackaged: true,
+    resourcesPath: "/missing/resources",
+    runningUnderArm64Translation: false,
+  }).pipe(
+    Layer.provide(
+      Layer.mergeAll(NodeServices.layer, DesktopConfig.layerTest({ T3CODE_HOME: baseDir })),
+    ),
+  );
+
+  const dependencies = Layer.mergeAll(
+    poolLayer,
+    httpClientLayer,
+    environmentLayer,
+    NodeServices.layer,
+  );
 
-      const [first, second] = yield* Effect.gen(function* () {
+  return Layer.mergeAll(
+    DesktopLocalEnvironmentAuth.layer.pipe(Layer.provide(dependencies)),
+    environmentLayer,
+  );
+}
+
+describe("DesktopLocalEnvironmentAuth", () => {
+  it.effect("exchanges the desktop bootstrap credential only once per persisted instance id", () =>
+    Effect.gen(function* () {
+      const fileSystem = yield* FileSystem.FileSystem;
+      const baseDir = yield* fileSystem.makeTempDirectoryScoped({
+        prefix: "t3-desktop-local-auth-test-",
+      });
+      const requestCount = yield* Ref.make(0);
+
+      const exchangeTwiceAndReadInstanceId = Effect.gen(function* () {
         const auth = yield* DesktopLocalEnvironmentAuth.DesktopLocalEnvironmentAuth;
-        return yield* Effect.all([auth.getBearerToken, auth.getBearerToken]);
-      }).pipe(Effect.provide(testLayer));
+        const environment = yield* DesktopEnvironment.DesktopEnvironment;
+        const path = yield* Path.Path;
+        const [first, second] = yield* Effect.all([auth.getBearerToken, auth.getBearerToken]);
+
+        assert.strictEqual(first, "desktop-bearer-token");
+        assert.strictEqual(second, "desktop-bearer-token");
+
+        const instanceIdPath = path.join(environment.stateDir, "client-instance-id");
+        return yield* fileSystem.readFileString(instanceIdPath);
+      }).pipe(Effect.provide(makeLayer(baseDir, requestCount)));
+
+      const storedInstanceId = yield* exchangeTwiceAndReadInstanceId;
 
-      assert.strictEqual(first, "desktop-bearer-token");
-      assert.strictEqual(second, "desktop-bearer-token");
+      assert.strictEqual(storedInstanceId.trim().length > 0, true);
       assert.strictEqual(yield* Ref.get(requestCount), 1);
-    }),
+    }).pipe(Effect.provide(NodeServices.layer), Effect.scoped),
   );
 });
diff --git a/apps/desktop/src/backend/DesktopLocalEnvironmentAuth.ts b/apps/desktop/src/backend/DesktopLocalEnvironmentAuth.ts
index 201492f0e..b80159e25 100644
--- a/apps/desktop/src/backend/DesktopLocalEnvironmentAuth.ts
+++ b/apps/desktop/src/backend/DesktopLocalEnvironmentAuth.ts
@@ -1,15 +1,19 @@
 import { bootstrapRemoteBearerSession } from "@t3tools/client-runtime/authorization";
 import { PRIMARY_LOCAL_ENVIRONMENT_ID } from "@t3tools/contracts";
 import * as Context from "effect/Context";
+import * as Crypto from "effect/Crypto";
 import * as Effect from "effect/Effect";
+import * as FileSystem from "effect/FileSystem";
 import * as Layer from "effect/Layer";
 import * as Option from "effect/Option";
+import * as Path from "effect/Path";
 import * as Ref from "effect/Ref";
 import * as Schema from "effect/Schema";
 import * as Semaphore from "effect/Semaphore";
 import * as HttpClient from "effect/unstable/http/HttpClient";
 
 import * as DesktopBackendPool from "./DesktopBackendPool.ts";
+import * as DesktopEnvironment from "../app/DesktopEnvironment.ts";
 
 export class DesktopLocalEnvironmentAuthBackendNotConfiguredError extends Schema.TaggedErrorClass<DesktopLocalEnvironmentAuthBackendNotConfiguredError>()(
   "DesktopLocalEnvironmentAuthBackendNotConfiguredError",
@@ -45,9 +49,48 @@ export class DesktopLocalEnvironmentAuth extends Context.Service<
 export const make = Effect.gen(function* () {
   const pool = yield* DesktopBackendPool.DesktopBackendPool;
   const httpClient = yield* HttpClient.HttpClient;
+  const fileSystem = yield* FileSystem.FileSystem;
+  const path = yield* Path.Path;
+  const crypto = yield* Crypto.Crypto;
+  const environment = yield* DesktopEnvironment.DesktopEnvironment;
   const tokenRef = yield* Ref.make(Option.none<string>());
+  const instanceIdRef = yield* Ref.make(Option.none<string>());
   const mutex = yield* Semaphore.make(1);
 
+  // Persisted once per desktop install so every launch reuses the same
+  // authorized-client session on the local backend instead of adding one.
+  const resolveInstanceId = Effect.gen(function* () {
+    const cached = yield* Ref.get(instanceIdRef);
+    if (Option.isSome(cached)) {
+      return cached.value;
+    }
+    const instanceIdPath = path.join(environment.stateDir, "client-instance-id");
+    const stored = yield* fileSystem.readFileString(instanceIdPath).pipe(Effect.option);
+    const instanceId =
+      Option.isSome(stored) && stored.value.trim() !== ""
+        ? stored.value.trim()
+        : yield* crypto.randomUUIDv4.pipe(
+            Effect.mapError(
+              (cause) => new DesktopLocalEnvironmentAuthSessionBootstrapError({ cause }),
+            ),
+          );
+    if (Option.isNone(stored)) {
+      yield* fileSystem
+        .makeDirectory(path.dirname(instanceIdPath), { recursive: true })
+        .pipe(Effect.ignore);
+      yield* fileSystem.writeFileString(instanceIdPath, `${instanceId}\n`).pipe(
+        Effect.catchCause((cause) =>
+          Effect.logWarning("Failed to persist the desktop client instance id.", {
+            instanceIdPath,
+            cause,
+          }),
+        ),
+      );
+    }
+    yield* Ref.set(instanceIdRef, Option.some(instanceId));
+    return instanceId;
+  }).pipe(Effect.withSpan("desktop.localEnvironmentAuth.resolveInstanceId"));
+
   const getBearerToken = mutex
     .withPermits(1)(
       Effect.gen(function* () {
@@ -73,6 +116,7 @@ export const make = Effect.gen(function* () {
           clientMetadata: {
             label: "T3 Code Desktop",
             deviceType: "desktop",
+            instanceId: yield* resolveInstanceId,
           },
         }).pipe(
           Effect.provideService(HttpClient.HttpClient, httpClient),
diff --git a/apps/mobile/src/connection/platform.ts b/apps/mobile/src/connection/platform.ts
index 852535d9d..68962c0ad 100644
--- a/apps/mobile/src/connection/platform.ts
+++ b/apps/mobile/src/connection/platform.ts
@@ -114,6 +114,7 @@ const wakeupsLayer = Wakeups.layer({
 const capabilitiesLayer = Layer.effectContext(
   Effect.gen(function* () {
     const storage = yield* MobileStorage.MobileStorage;
+    const clientInstanceId = yield* storage.loadOrCreateClientInstanceId.pipe(Effect.option);
     return Context.make(
       CloudSession,
       CloudSession.of({
@@ -166,7 +167,9 @@ const capabilitiesLayer = Layer.effectContext(
       Context.add(
         ClientPresentation,
         ClientPresentation.of({
-          metadata: authClientMetadata(),
+          metadata: authClientMetadata(
+            Option.isSome(clientInstanceId) ? { instanceId: clientInstanceId.value } : {},
+          ),
           scopes: AuthStandardClientScopes,
         }),
       ),
diff --git a/apps/mobile/src/features/agent-awareness/liveActivityPreferences.test.ts b/apps/mobile/src/features/agent-awareness/liveActivityPreferences.test.ts
index 0ee3e59b9..60d274878 100644
--- a/apps/mobile/src/features/agent-awareness/liveActivityPreferences.test.ts
+++ b/apps/mobile/src/features/agent-awareness/liveActivityPreferences.test.ts
@@ -56,6 +56,7 @@ const testLayer = Layer.mergeAll(
       saveConnection: () => Effect.void,
       clearSavedConnection: () => Effect.void,
       loadOrCreateAgentAwarenessDeviceId: Effect.succeed("device-1"),
+      loadOrCreateClientInstanceId: Effect.succeed("client-instance-1"),
       loadAgentAwarenessDeviceId: Effect.succeed("device-1"),
       loadAgentAwarenessRegistrationRecord: Effect.succeed(null),
       saveAgentAwarenessRegistrationRecord: () => Effect.void,
diff --git a/apps/mobile/src/features/cloud/linkEnvironment.test.ts b/apps/mobile/src/features/cloud/linkEnvironment.test.ts
index c75d60d5f..acfada81c 100644
--- a/apps/mobile/src/features/cloud/linkEnvironment.test.ts
+++ b/apps/mobile/src/features/cloud/linkEnvironment.test.ts
@@ -90,6 +90,7 @@ function cloudClientLayer() {
         saveConnection: () => Effect.void,
         clearSavedConnection: () => Effect.void,
         loadOrCreateAgentAwarenessDeviceId: Effect.succeed("device-1"),
+        loadOrCreateClientInstanceId: Effect.succeed("client-instance-1"),
         loadAgentAwarenessDeviceId: Effect.succeed("device-1"),
         loadAgentAwarenessRegistrationRecord: Effect.succeed(null),
         saveAgentAwarenessRegistrationRecord: () => Effect.void,
@@ -489,6 +490,7 @@ describe("mobile cloud link environment client", () => {
       expect(environmentTokenBody.get("client_label")).toBe("T3 Code Mobile");
       expect(environmentTokenBody.get("client_device_type")).toBe("mobile");
       expect(environmentTokenBody.get("client_os")).toBe("iOS");
+      expect(environmentTokenBody.get("client_instance_id")).toBe("client-instance-1");
     }),
   );
 
diff --git a/apps/mobile/src/features/cloud/linkEnvironment.ts b/apps/mobile/src/features/cloud/linkEnvironment.ts
index 958827ee4..7cf531549 100644
--- a/apps/mobile/src/features/cloud/linkEnvironment.ts
+++ b/apps/mobile/src/features/cloud/linkEnvironment.ts
@@ -497,6 +497,13 @@ const loadAgentAwarenessDeviceId = Effect.fn("mobile.cloud.loadAgentAwarenessDev
   },
 );
 
+const loadClientInstanceId = Effect.fn("mobile.cloud.loadClientInstanceId")(function* () {
+  const storage = yield* MobileStorage.MobileStorage;
+  return yield* storage.loadOrCreateClientInstanceId.pipe(
+    Effect.mapError(cloudEnvironmentLinkError("Could not load the client instance id.")),
+  );
+});
+
 const connectRelayManagedEnvironment = Effect.fn("mobile.cloud.connectRelayManagedEnvironment")(
   function* (input: {
     readonly clerkToken: string;
@@ -557,7 +564,7 @@ const connectRelayManagedEnvironment = Effect.fn("mobile.cloud.connectRelayManag
       httpBaseUrl: connect.endpoint.httpBaseUrl,
       credential: connect.credential,
       dpopProof: bootstrapDpop,
-      clientMetadata: authClientMetadata(),
+      clientMetadata: authClientMetadata({ instanceId: yield* loadClientInstanceId() }),
     }).pipe(
       Effect.mapError(
         cloudEnvironmentLinkError("Could not exchange a managed endpoint DPoP access token."),
diff --git a/apps/mobile/src/lib/authClientMetadata.ts b/apps/mobile/src/lib/authClientMetadata.ts
index 09897b618..d15bd3912 100644
--- a/apps/mobile/src/lib/authClientMetadata.ts
+++ b/apps/mobile/src/lib/authClientMetadata.ts
@@ -1,10 +1,13 @@
 import type { AuthClientPresentationMetadata } from "@t3tools/contracts";
 import { Platform } from "react-native";
 
-export function authClientMetadata(): AuthClientPresentationMetadata {
+export function authClientMetadata(
+  input: { readonly instanceId?: string } = {},
+): AuthClientPresentationMetadata {
   return {
     label: "T3 Code Mobile",
     deviceType: "mobile",
     ...(Platform.OS === "ios" ? { os: "iOS" } : Platform.OS === "android" ? { os: "Android" } : {}),
+    ...(input.instanceId ? { instanceId: input.instanceId } : {}),
   };
 }
diff --git a/apps/mobile/src/persistence/mobile-storage.ts b/apps/mobile/src/persistence/mobile-storage.ts
index 266e8c1a9..f80544f70 100644
--- a/apps/mobile/src/persistence/mobile-storage.ts
+++ b/apps/mobile/src/persistence/mobile-storage.ts
@@ -17,6 +17,7 @@ const CONNECTIONS_KEY = "t3code.connections";
 const AGENT_AWARENESS_DEVICE_ID_KEY = "t3code.agent-awareness.device-id";
 const AGENT_AWARENESS_REGISTRATION_KEY = "t3code.agent-awareness.registration";
 const RECENT_THREAD_SHORTCUTS_KEY = "t3code.recent-thread-shortcuts";
+const CLIENT_INSTANCE_ID_KEY = "t3code.client-instance-id";
 
 export class MobileStorageDecodeError extends Schema.TaggedErrorClass<MobileStorageDecodeError>()(
   "MobileStorageDecodeError",
@@ -86,6 +87,10 @@ export class MobileStorage extends Context.Service<
       string,
       MobileSecureStorage.MobileSecureStorageError | MobileDeviceIdGenerationError
     >;
+    readonly loadOrCreateClientInstanceId: Effect.Effect<
+      string,
+      MobileSecureStorage.MobileSecureStorageError | MobileDeviceIdGenerationError
+    >;
     readonly loadAgentAwarenessDeviceId: Effect.Effect<
       string | null,
       MobileSecureStorage.MobileSecureStorageError
@@ -199,6 +204,19 @@ export const make = Effect.fn("MobileStorage.make")(function* () {
     return deviceId;
   });
 
+  // Stable per-install id presented during auth bootstrap so repeated
+  // connections reuse one authorized-client session per environment.
+  const loadOrCreateClientInstanceId = Effect.gen(function* () {
+    const existing = yield* secureStorage.getItem(CLIENT_INSTANCE_ID_KEY);
+    if (existing?.trim()) return existing;
+    const instanceId = yield* Effect.tryPromise({
+      try: () => import("../lib/uuid").then(({ uuidv4 }) => uuidv4()),
+      catch: (cause) => new MobileDeviceIdGenerationError({ cause }),
+    });
+    yield* secureStorage.setItem(CLIENT_INSTANCE_ID_KEY, instanceId);
+    return instanceId;
+  });
+
   const loadAgentAwarenessDeviceId = secureStorage
     .getItem(AGENT_AWARENESS_DEVICE_ID_KEY)
     .pipe(Effect.map((existing) => (existing?.trim() ? existing : null)));
@@ -250,6 +268,7 @@ export const make = Effect.fn("MobileStorage.make")(function* () {
     saveConnection,
     clearSavedConnection,
     loadOrCreateAgentAwarenessDeviceId,
+    loadOrCreateClientInstanceId,
     loadAgentAwarenessDeviceId,
     loadAgentAwarenessRegistrationRecord,
     saveAgentAwarenessRegistrationRecord: (record) =>
diff --git a/apps/server/src/auth/SessionStore.test.ts b/apps/server/src/auth/SessionStore.test.ts
index 334c24ef5..a4ce639ef 100644
--- a/apps/server/src/auth/SessionStore.test.ts
+++ b/apps/server/src/auth/SessionStore.test.ts
@@ -47,6 +47,9 @@ const failingSessionLookupRepositoryLayer = Layer.succeed(AuthSessions.AuthSessi
   revoke: () => Effect.fail(repositoryFailure),
   revokeAllExcept: () => Effect.fail(repositoryFailure),
   setLastConnectedAt: () => Effect.void,
+  listActiveForIdentity: () => Effect.succeed([]),
+  updateExpiration: () => Effect.void,
+  prune: () => Effect.succeed(0),
 });
 
 const failingSessionLookupCredentialLayer = Layer.effect(
@@ -274,6 +277,95 @@ it.layer(NodeServices.layer)("SessionStore.layer", (it) => {
     }).pipe(Effect.provide(makeSessionStoreLayer())),
   );
 
+  it.effect("collapses repeated bootstraps from one client instance onto a single session", () =>
+    Effect.gen(function* () {
+      const sessions = yield* SessionStore.SessionStore;
+      const client = { label: "T3 Code Desktop", deviceType: "desktop" as const };
+      const first = yield* sessions.issue({
+        method: "bearer-access-token",
+        subject: "desktop-bootstrap",
+        scopes: ["orchestration:read"],
+        client: { ...client, instanceId: "instance-1" },
+      });
+      yield* TestClock.adjust(Duration.minutes(1));
+      const second = yield* sessions.issue({
+        method: "bearer-access-token",
+        subject: "desktop-bootstrap",
+        scopes: ["orchestration:read"],
+        client: { ...client, instanceId: "instance-1" },
+      });
+      const thirdFromAnotherInstance = yield* sessions.issue({
+        method: "bearer-access-token",
+        subject: "desktop-bootstrap",
+        scopes: ["orchestration:read"],
+        client: { ...client, instanceId: "instance-2" },
+      });
+
+      expect(second.sessionId).toBe(first.sessionId);
+      expect(second.token).not.toBe(first.token);
+      expect(thirdFromAnotherInstance.sessionId).not.toBe(first.sessionId);
+      expect(second.expiresAt.epochMilliseconds).toBeGreaterThan(first.expiresAt.epochMilliseconds);
+      expect(yield* sessions.verify(first.token)).toMatchObject({ sessionId: first.sessionId });
+      expect(yield* sessions.verify(second.token)).toMatchObject({ sessionId: first.sessionId });
+
+      const active = yield* sessions.listActive();
+      expect(active).toHaveLength(2);
+      expect(active.filter((entry) => entry.client.instanceId === "instance-1")).toHaveLength(1);
+    }).pipe(Effect.provide(makeSessionStoreLayer())),
+  );
+
+  it.effect("replaces an instance session when requested scopes widen", () =>
+    Effect.gen(function* () {
+      const sessions = yield* SessionStore.SessionStore;
+      const narrow = yield* sessions.issue({
+        method: "bearer-access-token",
+        subject: "desktop-bootstrap",
+        scopes: ["orchestration:read"],
+        client: { label: "Desktop", deviceType: "desktop", instanceId: "instance-1" },
+      });
+      const widened = yield* sessions.issue({
+        method: "bearer-access-token",
+        subject: "desktop-bootstrap",
+        scopes: ["orchestration:read", "access:write"],
+        client: { label: "Desktop", deviceType: "desktop", instanceId: "instance-1" },
+      });
+
+      expect(widened.sessionId).not.toBe(narrow.sessionId);
+      // Rotated-away sessions are revoked and then pruned immediately, so the
+      // old token no longer resolves to a session at all.
+      const rejected = yield* Effect.flip(sessions.verify(narrow.token));
+      expect(rejected._tag).toBe("UnknownSessionTokenError");
+      expect((yield* sessions.listActive()).map((entry) => entry.sessionId)).toEqual([
+        widened.sessionId,
+      ]);
+    }).pipe(Effect.provide(makeSessionStoreLayer())),
+  );
+
+  it.effect("prunes expired and revoked sessions on issuance", () =>
+    Effect.gen(function* () {
+      const sessions = yield* SessionStore.SessionStore;
+      yield* sessions.issue({
+        method: "bearer-access-token",
+        subject: "short-lived",
+        ttl: Duration.seconds(1),
+      });
+      const revoked = yield* sessions.issue({ subject: "revoked-soon" });
+      yield* sessions.revoke(revoked.sessionId);
+
+      yield* TestClock.adjust(Duration.seconds(2));
+      const replacement = yield* sessions.issue({
+        method: "bearer-access-token",
+        subject: "replacement",
+      });
+
+      expect((yield* sessions.listActive()).map((entry) => entry.sessionId)).toEqual([
+        replacement.sessionId,
+      ]);
+      const prunedRevoked = yield* Effect.flip(sessions.verify(revoked.token));
+      expect(prunedRevoked._tag).toBe("UnknownSessionTokenError");
+    }).pipe(Effect.provide(Layer.merge(makeSessionStoreLayer(), TestClock.layer()))),
+  );
+
   it.effect("persists lastConnectedAt on first connect and updates it after reconnect", () =>
     Effect.gen(function* () {
       const sessions = yield* SessionStore.SessionStore;
diff --git a/apps/server/src/auth/SessionStore.ts b/apps/server/src/auth/SessionStore.ts
index 40a1c43e0..5b5626acb 100644
--- a/apps/server/src/auth/SessionStore.ts
+++ b/apps/server/src/auth/SessionStore.ts
@@ -441,6 +441,7 @@ function toClientMetadata(record: {
   readonly deviceType: AuthClientMetadata["deviceType"];
   readonly os: string | null;
   readonly browser: string | null;
+  readonly instanceId: string | null;
 }): AuthClientMetadata {
   return {
     ...(record.label ? { label: record.label } : {}),
@@ -449,6 +450,7 @@ function toClientMetadata(record: {
     deviceType: record.deviceType,
     ...(record.os ? { os: record.os } : {}),
     ...(record.browser ? { browser: record.browser } : {}),
+    ...(record.instanceId ? { instanceId: record.instanceId } : {}),
   };
 }
 
@@ -501,7 +503,7 @@ export const make = Effect.gen(function* () {
           subject: row.value.subject,
           scopes: row.value.scopes,
           method: row.value.method,
-          client: toClientMetadata(row.value.client),
+          client: toClientMetadata({ ...row.value.client, instanceId: row.value.instanceId }),
           issuedAt: row.value.issuedAt,
           expiresAt: row.value.expiresAt,
           lastConnectedAt: row.value.lastConnectedAt,
@@ -571,24 +573,118 @@ export const make = Effect.gen(function* () {
     );
 
   const encodeClaims = Schema.encodeEffect(Schema.fromJsonString(SessionClaims));
+
   const issue: SessionStore["Service"]["issue"] = Effect.fn("SessionStore.issue")(
     function* (input) {
+      const now = yield* DateTime.now;
+      const client = input?.client ?? createDefaultClientMetadata();
+      const subject = input?.subject ?? "browser";
+      const method = input?.method ?? "browser-session-cookie";
+      const scopes = input?.scopes ?? AuthStandardClientScopes;
+      const expiresAt = DateTime.add(now, {
+        milliseconds: Duration.toMillis(input?.ttl ?? DEFAULT_SESSION_TTL),
+      });
+
+      // A client that presents a stable instance id collapses repeated
+      // bootstraps onto its existing session instead of accumulating rows.
+      // DPoP credentials are excluded because their key thumbprint is not
+      // persisted, so a reused session could not be safely re-signed.
+      if (client.instanceId !== undefined && input?.proofKeyThumbprint === undefined) {
+        const candidates = yield* authSessions
+          .listActiveForIdentity({
+            now,
+            subject,
+            method,
+            instanceId: client.instanceId,
+          })
+          .pipe(Effect.mapError((cause) => new SessionCredentialIssueError({ cause })));
+        const reusable = candidates.find((row) =>
+          scopes.every((scope) => row.scopes.includes(scope)),
+        );
+        if (reusable !== undefined) {
+          yield* authSessions
+            .updateExpiration({ sessionId: reusable.sessionId, expiresAt })
+            .pipe(
+              Effect.mapError(
+                (cause) =>
+                  new SessionCredentialIssueError({ sessionId: reusable.sessionId, cause }),
+              ),
+            );
+          const claims: SessionClaims = {
+            v: 1,
+            kind: "session",
+            sid: reusable.sessionId,
+            sub: reusable.subject,
+            scopes: reusable.scopes,
+            method: reusable.method,
+            iat: now.epochMilliseconds,
+            exp: expiresAt.epochMilliseconds,
+          };
+          const token = yield* encodeClaims(claims).pipe(
+            Effect.map(base64UrlEncode),
+            Effect.map(
+              (encodedPayload) => `${encodedPayload}.${signPayload(encodedPayload, signingSecret)}`,
+            ),
+            Effect.mapError(
+              (cause) =>
+                new SessionCredentialIssueError({
+                  sessionId: reusable.sessionId,
+                  cause: new SessionClaimsEncodingError({
+                    sessionId: reusable.sessionId,
+                    operation: "encode_session_claims",
+                    cause,
+                  }),
+                }),
+            ),
+          );
+          yield* loadActiveSession(reusable.sessionId).pipe(
+            Effect.flatMap((session) =>
+              Option.isSome(session) ? emitUpsert(session.value) : Effect.void,
+            ),
+            Effect.catchCause((cause) =>
+              Effect.logError("Failed to publish reused-session auth update.").pipe(
+                Effect.annotateLogs({
+                  sessionId: reusable.sessionId,
+                  cause,
+                }),
+              ),
+            ),
+          );
+          return {
+            sessionId: reusable.sessionId,
+            token,
+            method: reusable.method,
+            client,
+            expiresAt,
+            scopes: reusable.scopes,
+          } satisfies IssuedSession;
+        }
+        for (const stale of candidates) {
+          yield* authSessions
+            .revoke({ sessionId: stale.sessionId, revokedAt: now })
+            .pipe(Effect.mapError((cause) => new SessionCredentialIssueError({ cause })));
+          yield* Ref.update(connectedSessionsRef, (current) => {
+            const next = new Map(current);
+            next.delete(stale.sessionId);
+            return next;
+          });
+          yield* emitRemoved(stale.sessionId);
+        }
+      }
+
       const sessionId = AuthSessionId.make(
         yield* crypto.randomUUIDv4.pipe(
           Effect.mapError((cause) => new SessionCredentialIssueError({ cause })),
         ),
       );
-      const issuedAt = yield* DateTime.now;
-      const expiresAt = DateTime.add(issuedAt, {
-        milliseconds: Duration.toMillis(input?.ttl ?? DEFAULT_SESSION_TTL),
-      });
+      const issuedAt = now;
       const claims: SessionClaims = {
         v: 1,
         kind: "session",
         sid: sessionId,
-        sub: input?.subject ?? "browser",
-        scopes: input?.scopes ?? AuthStandardClientScopes,
-        method: input?.method ?? "browser-session-cookie",
+        sub: subject,
+        scopes,
+        method,
         ...(input?.proofKeyThumbprint ? { jkt: input.proofKeyThumbprint } : {}),
         iat: issuedAt.epochMilliseconds,
         exp: expiresAt.epochMilliseconds,
@@ -609,7 +705,6 @@ export const make = Effect.gen(function* () {
         ),
       );
       const signature = signPayload(encodedPayload, signingSecret);
-      const client = input?.client ?? createDefaultClientMetadata();
       yield* authSessions
         .create({
           sessionId,
@@ -624,10 +719,18 @@ export const make = Effect.gen(function* () {
             os: client.os ?? null,
             browser: client.browser ?? null,
           },
+          instanceId: client.instanceId ?? null,
           issuedAt,
           expiresAt,
         })
         .pipe(Effect.mapError((cause) => new SessionCredentialIssueError({ sessionId, cause })));
+      yield* authSessions
+        .prune({ now })
+        .pipe(
+          Effect.catchCause((cause) =>
+            Effect.logWarning("Failed to prune expired auth sessions.", { cause }),
+          ),
+        );
       yield* emitUpsert(
         toAuthClientSession({
           sessionId,
@@ -707,7 +810,7 @@ export const make = Effect.gen(function* () {
         sessionId: claims.sid,
         token,
         method: claims.method,
-        client: toClientMetadata(row.value.client),
+        client: toClientMetadata({ ...row.value.client, instanceId: row.value.instanceId }),
         expiresAt: expiresAt.value,
         subject: claims.sub,
         scopes: claims.scopes,
@@ -813,7 +916,7 @@ export const make = Effect.gen(function* () {
       sessionId: row.value.sessionId,
       token,
       method: row.value.method,
-      client: toClientMetadata(row.value.client),
+      client: toClientMetadata({ ...row.value.client, instanceId: row.value.instanceId }),
       expiresAt: row.value.expiresAt,
       subject: row.value.subject,
       scopes: row.value.scopes,
@@ -832,7 +935,7 @@ export const make = Effect.gen(function* () {
           subject: row.subject,
           scopes: row.scopes,
           method: row.method,
-          client: toClientMetadata(row.client),
+          client: toClientMetadata({ ...row.client, instanceId: row.instanceId }),
           issuedAt: row.issuedAt,
           expiresAt: row.expiresAt,
           lastConnectedAt: row.lastConnectedAt,
diff --git a/apps/server/src/auth/http.ts b/apps/server/src/auth/http.ts
index 780aaabde..cfef85d7a 100644
--- a/apps/server/src/auth/http.ts
+++ b/apps/server/src/auth/http.ts
@@ -300,6 +300,9 @@ export const authHttpApiLayer = HttpApiBuilder.group(
                     ? { deviceType: args.payload.client_device_type }
                     : {}),
                   ...(args.payload.client_os ? { os: args.payload.client_os } : {}),
+                  ...(args.payload.client_instance_id
+                    ? { instanceId: args.payload.client_instance_id }
+                    : {}),
                 },
               }),
               proofKeyThumbprint ? { proofKeyThumbprint } : undefined,
diff --git a/apps/server/src/auth/utils.ts b/apps/server/src/auth/utils.ts
index 32a6799b0..6773e9f34 100644
--- a/apps/server/src/auth/utils.ts
+++ b/apps/server/src/auth/utils.ts
@@ -180,5 +180,6 @@ export function deriveAuthClientMetadata(input: {
     deviceType: input.presented?.deviceType ?? inferDeviceType(userAgent),
     ...(os ? { os } : {}),
     ...(browser ? { browser } : {}),
+    ...(input.presented?.instanceId ? { instanceId: input.presented.instanceId } : {}),
   };
 }
diff --git a/apps/server/src/persistence/AuthSessions.ts b/apps/server/src/persistence/AuthSessions.ts
index 545688e38..9b2bd9018 100644
--- a/apps/server/src/persistence/AuthSessions.ts
+++ b/apps/server/src/persistence/AuthSessions.ts
@@ -36,6 +36,7 @@ export const AuthSessionRecord = Schema.Struct({
   scopes: AuthEnvironmentScopes,
   method: ServerAuthSessionMethod,
   client: AuthSessionClientMetadataRecord,
+  instanceId: Schema.NullOr(Schema.String),
   issuedAt: Schema.DateTimeUtcFromString,
   expiresAt: Schema.DateTimeUtcFromString,
   lastConnectedAt: Schema.NullOr(Schema.DateTimeUtcFromString),
@@ -49,6 +50,7 @@ export const CreateAuthSessionInput = Schema.Struct({
   scopes: AuthEnvironmentScopes,
   method: ServerAuthSessionMethod,
   client: AuthSessionClientMetadataRecord,
+  instanceId: Schema.NullOr(Schema.String),
   issuedAt: Schema.DateTimeUtcFromString,
   expiresAt: Schema.DateTimeUtcFromString,
 });
@@ -82,6 +84,26 @@ export const SetAuthSessionLastConnectedAtInput = Schema.Struct({
 });
 export type SetAuthSessionLastConnectedAtInput = typeof SetAuthSessionLastConnectedAtInput.Type;
 
+export const ListActiveAuthSessionsForIdentityInput = Schema.Struct({
+  now: Schema.DateTimeUtcFromString,
+  subject: Schema.String,
+  method: ServerAuthSessionMethod,
+  instanceId: Schema.String,
+});
+export type ListActiveAuthSessionsForIdentityInput =
+  typeof ListActiveAuthSessionsForIdentityInput.Type;
+
+export const UpdateAuthSessionExpirationInput = Schema.Struct({
+  sessionId: AuthSessionId,
+  expiresAt: Schema.DateTimeUtcFromString,
+});
+export type UpdateAuthSessionExpirationInput = typeof UpdateAuthSessionExpirationInput.Type;
+
+export const PruneAuthSessionsInput = Schema.Struct({
+  now: Schema.DateTimeUtcFromString,
+});
+export type PruneAuthSessionsInput = typeof PruneAuthSessionsInput.Type;
+
 export class AuthSessionRepository extends Context.Service<
   AuthSessionRepository,
   {
@@ -103,6 +125,15 @@ export class AuthSessionRepository extends Context.Service<
     readonly setLastConnectedAt: (
       input: SetAuthSessionLastConnectedAtInput,
     ) => Effect.Effect<void, AuthSessionRepositoryError>;
+    readonly listActiveForIdentity: (
+      input: ListActiveAuthSessionsForIdentityInput,
+    ) => Effect.Effect<ReadonlyArray<AuthSessionRecord>, AuthSessionRepositoryError>;
+    readonly updateExpiration: (
+      input: UpdateAuthSessionExpirationInput,
+    ) => Effect.Effect<void, AuthSessionRepositoryError>;
+    readonly prune: (
+      input: PruneAuthSessionsInput,
+    ) => Effect.Effect<number, AuthSessionRepositoryError>;
   }
 >()("t3/persistence/AuthSessions/AuthSessionRepository") {}
 
@@ -117,6 +148,7 @@ const AuthSessionDbRow = Schema.Struct({
   clientDeviceType: Schema.Literals(["desktop", "mobile", "tablet", "bot", "unknown"]),
   clientOs: Schema.NullOr(Schema.String),
   clientBrowser: Schema.NullOr(Schema.String),
+  clientInstanceId: Schema.NullOr(Schema.String),
   issuedAt: Schema.DateTimeUtcFromString,
   expiresAt: Schema.DateTimeUtcFromString,
   lastConnectedAt: Schema.NullOr(Schema.DateTimeUtcFromString),
@@ -134,6 +166,7 @@ const AuthSessionRawDbRow = Schema.Struct({
   clientDeviceType: Schema.Unknown,
   clientOs: Schema.Unknown,
   clientBrowser: Schema.Unknown,
+  clientInstanceId: Schema.Unknown,
   issuedAt: Schema.Unknown,
   expiresAt: Schema.Unknown,
   lastConnectedAt: Schema.Unknown,
@@ -156,6 +189,7 @@ function toAuthSessionRecord(row: typeof AuthSessionDbRow.Type): AuthSessionReco
       os: row.clientOs,
       browser: row.clientBrowser,
     },
+    instanceId: row.clientInstanceId,
     issuedAt: row.issuedAt,
     expiresAt: row.expiresAt,
     lastConnectedAt: row.lastConnectedAt,
@@ -196,6 +230,7 @@ export const make = Effect.gen(function* () {
           client_device_type,
           client_os,
           client_browser,
+          client_instance_id,
           issued_at,
           expires_at,
           revoked_at
@@ -211,6 +246,7 @@ export const make = Effect.gen(function* () {
           ${input.client.deviceType},
           ${input.client.os},
           ${input.client.browser},
+          ${input.instanceId},
           ${input.issuedAt},
           ${input.expiresAt},
           NULL
@@ -218,56 +254,44 @@ export const make = Effect.gen(function* () {
       `,
   });
 
+  const sessionRowSelection = sql`
+    SELECT
+      session_id AS "sessionId",
+      subject AS "subject",
+      scopes AS "scopes",
+      method AS "method",
+      client_label AS "clientLabel",
+      client_ip_address AS "clientIpAddress",
+      client_user_agent AS "clientUserAgent",
+      client_device_type AS "clientDeviceType",
+      client_os AS "clientOs",
+      client_browser AS "clientBrowser",
+      client_instance_id AS "clientInstanceId",
+      issued_at AS "issuedAt",
+      expires_at AS "expiresAt",
+      last_connected_at AS "lastConnectedAt",
+      revoked_at AS "revokedAt"
+    FROM auth_sessions
+  `;
+
   const getSessionRowById = SqlSchema.findOneOption({
     Request: GetAuthSessionByIdInput,
     Result: AuthSessionRawDbRow,
-    execute: ({ sessionId }) =>
-      sql`
-        SELECT
-          session_id AS "sessionId",
-          subject AS "subject",
-          scopes AS "scopes",
-          method AS "method",
-          client_label AS "clientLabel",
-          client_ip_address AS "clientIpAddress",
-          client_user_agent AS "clientUserAgent",
-          client_device_type AS "clientDeviceType",
-          client_os AS "clientOs",
-          client_browser AS "clientBrowser",
-          issued_at AS "issuedAt",
-          expires_at AS "expiresAt",
-          last_connected_at AS "lastConnectedAt",
-          revoked_at AS "revokedAt"
-        FROM auth_sessions
-        WHERE session_id = ${sessionId}
-      `,
+    execute: ({ sessionId }) => sql`${sessionRowSelection} WHERE session_id = ${sessionId}`,
   });
 
   const listActiveSessionRows = SqlSchema.findAll({
     Request: ListActiveAuthSessionsInput,
     Result: AuthSessionRawDbRow,
     execute: ({ now }) =>
-      sql`
-        SELECT
-          session_id AS "sessionId",
-          subject AS "subject",
-          scopes AS "scopes",
-          method AS "method",
-          client_label AS "clientLabel",
-          client_ip_address AS "clientIpAddress",
-          client_user_agent AS "clientUserAgent",
-          client_device_type AS "clientDeviceType",
-          client_os AS "clientOs",
-          client_browser AS "clientBrowser",
-          issued_at AS "issuedAt",
-          expires_at AS "expiresAt",
-          last_connected_at AS "lastConnectedAt",
-          revoked_at AS "revokedAt"
-        FROM auth_sessions
-        WHERE revoked_at IS NULL
-          AND expires_at > ${now}
-        ORDER BY issued_at DESC, session_id DESC
-      `,
+      sql`${sessionRowSelection} WHERE revoked_at IS NULL AND expires_at > ${now} ORDER BY issued_at DESC, session_id DESC`,
+  });
+
+  const listActiveSessionRowsForIdentity = SqlSchema.findAll({
+    Request: ListActiveAuthSessionsForIdentityInput,
+    Result: AuthSessionRawDbRow,
+    execute: ({ now, subject, method, instanceId }) =>
+      sql`${sessionRowSelection} WHERE subject = ${subject} AND method = ${method} AND client_instance_id = ${instanceId} AND revoked_at IS NULL AND expires_at > ${now} ORDER BY issued_at DESC`,
   });
 
   const setLastConnectedAtRow = SqlSchema.void({
@@ -281,6 +305,29 @@ export const make = Effect.gen(function* () {
       `,
   });
 
+  const updateSessionExpirationRow = SqlSchema.void({
+    Request: UpdateAuthSessionExpirationInput,
+    execute: ({ sessionId, expiresAt }) =>
+      sql`
+        UPDATE auth_sessions
+        SET expires_at = ${expiresAt}
+        WHERE session_id = ${sessionId}
+          AND revoked_at IS NULL
+      `,
+  });
+
+  const prunedSessionRows = SqlSchema.findAll({
+    Request: PruneAuthSessionsInput,
+    Result: Schema.Struct({ sessionId: AuthSessionId }),
+    execute: ({ now }) =>
+      sql`
+        DELETE FROM auth_sessions
+        WHERE expires_at <= ${now}
+          OR revoked_at IS NOT NULL
+        RETURNING session_id AS "sessionId"
+      `,
+  });
+
   const revokeSessionRows = SqlSchema.findAll({
     Request: RevokeAuthSessionInput,
     Result: Schema.Struct({ sessionId: AuthSessionId }),
@@ -404,6 +451,55 @@ export const make = Effect.gen(function* () {
       ),
     );
 
+  const listActiveForIdentity: AuthSessionRepository["Service"]["listActiveForIdentity"] = (
+    input,
+  ) =>
+    listActiveSessionRowsForIdentity(input).pipe(
+      Effect.mapError(
+        toPersistenceSqlOrDecodeError(
+          "AuthSessionRepository.listActiveForIdentity:query",
+          "AuthSessionRepository.listActiveForIdentity:decodeRows",
+          { instanceId: input.instanceId },
+        ),
+      ),
+      Effect.flatMap((rows) =>
+        Effect.forEach(rows, (row) =>
+          decodeAuthSessionDbRow(row).pipe(
+            Effect.mapError((cause) =>
+              PersistenceDecodeError.fromSchemaError(
+                "AuthSessionRepository.listActiveForIdentity:decodeRows",
+                cause,
+                { instanceId: input.instanceId },
+              ),
+            ),
+            Effect.map(toAuthSessionRecord),
+          ),
+        ),
+      ),
+    );
+
+  const updateExpiration: AuthSessionRepository["Service"]["updateExpiration"] = (input) =>
+    updateSessionExpirationRow(input).pipe(
+      Effect.mapError(
+        toPersistenceSqlOrDecodeError(
+          "AuthSessionRepository.updateExpiration:query",
+          "AuthSessionRepository.updateExpiration:encodeRequest",
+          { sessionId: input.sessionId },
+        ),
+      ),
+    );
+
+  const prune: AuthSessionRepository["Service"]["prune"] = (input) =>
+    prunedSessionRows(input).pipe(
+      Effect.mapError(
+        toPersistenceSqlOrDecodeError(
+          "AuthSessionRepository.prune:query",
+          "AuthSessionRepository.prune:decodeRows",
+        ),
+      ),
+      Effect.map((rows) => rows.length),
+    );
+
   return {
     create,
     getById,
@@ -411,6 +507,9 @@ export const make = Effect.gen(function* () {
     revoke,
     revokeAllExcept,
     setLastConnectedAt,
+    listActiveForIdentity,
+    updateExpiration,
+    prune,
   } satisfies AuthSessionRepository["Service"];
 });
 
diff --git a/apps/server/src/persistence/Errors.ts b/apps/server/src/persistence/Errors.ts
index 03edaec77..865d3810a 100644
--- a/apps/server/src/persistence/Errors.ts
+++ b/apps/server/src/persistence/Errors.ts
@@ -24,6 +24,7 @@ export const PersistenceErrorCorrelation = Schema.Union([
   Schema.Struct({ currentSessionId: Schema.String }),
   Schema.Struct({ pairingLinkId: Schema.String }),
   Schema.Struct({ threadId: Schema.String }),
+  Schema.Struct({ instanceId: Schema.String }),
 ]);
 export type PersistenceErrorCorrelation = typeof PersistenceErrorCorrelation.Type;
 
diff --git a/apps/server/src/persistence/Migrations.ts b/apps/server/src/persistence/Migrations.ts
index b137cedfb..62c3d3e90 100644
--- a/apps/server/src/persistence/Migrations.ts
+++ b/apps/server/src/persistence/Migrations.ts
@@ -53,6 +53,7 @@ import Migration0037 from "./Migrations/037_ProjectionTurnsKeysetIndex.ts";
 import Migration0038 from "./Migrations/038_ProjectionThreadsPinOrderKey.ts";
 import Migration0039 from "./Migrations/039_ProjectionProjectsDefaultThreadEnvMode.ts";
 import Migration0040 from "./Migrations/040_ProjectionProjectFaviconPath.ts";
+import Migration0041 from "./Migrations/041_AuthSessionClientInstanceId.ts";
 
 /**
  * Migration loader with all migrations defined inline.
@@ -105,6 +106,7 @@ export const migrationEntries = [
   [38, "ProjectionThreadsPinOrderKey", Migration0038],
   [39, "ProjectionProjectsDefaultThreadEnvMode", Migration0039],
   [40, "ProjectionProjectFaviconPath", Migration0040],
+  [41, "AuthSessionClientInstanceId", Migration0041],
 ] as const;
 
 export const migrationManifest = migrationEntries.map(([id, name]) => [id, name] as const);
diff --git a/apps/server/src/persistence/Migrations/041_AuthSessionClientInstanceId.ts b/apps/server/src/persistence/Migrations/041_AuthSessionClientInstanceId.ts
new file mode 100644
index 000000000..1b4823f65
--- /dev/null
+++ b/apps/server/src/persistence/Migrations/041_AuthSessionClientInstanceId.ts
@@ -0,0 +1,17 @@
+import * as Effect from "effect/Effect";
+import * as SqlClient from "effect/unstable/sql/SqlClient";
+
+export default Effect.gen(function* () {
+  const sql = yield* SqlClient.SqlClient;
+
+  const sessionColumns = yield* sql<{ readonly name: string }>`
+    PRAGMA table_info(auth_sessions)
+  `;
+
+  if (!sessionColumns.some((column) => column.name === "client_instance_id")) {
+    yield* sql`
+      ALTER TABLE auth_sessions
+      ADD COLUMN client_instance_id TEXT
+    `;
+  }
+});
diff --git a/apps/server/src/persistence/RepositoryErrorCorrelation.test.ts b/apps/server/src/persistence/RepositoryErrorCorrelation.test.ts
index 379b06e2a..426472b27 100644
--- a/apps/server/src/persistence/RepositoryErrorCorrelation.test.ts
+++ b/apps/server/src/persistence/RepositoryErrorCorrelation.test.ts
@@ -46,6 +46,7 @@ describe("persistence error correlation", () => {
           os: null,
           browser: null,
         },
+        instanceId: null,
         issuedAt,
         expiresAt,
       });
@@ -81,6 +82,7 @@ describe("persistence error correlation", () => {
             os: null,
             browser: null,
           },
+          instanceId: null,
           issuedAt,
           expiresAt,
         }),
diff --git a/apps/server/src/server.test.ts b/apps/server/src/server.test.ts
index 7cda53f25..3d1f6df9f 100644
--- a/apps/server/src/server.test.ts
+++ b/apps/server/src/server.test.ts
@@ -1057,6 +1057,7 @@ const exchangeAccessToken = (
       readonly label?: string;
       readonly deviceType?: string;
       readonly os?: string;
+      readonly instanceId?: string;
     };
   },
 ) =>
@@ -1081,6 +1082,9 @@ const exchangeAccessToken = (
           ? { client_device_type: options.clientMetadata.deviceType }
           : {}),
         ...(options?.clientMetadata?.os ? { client_os: options.clientMetadata.os } : {}),
+        ...(options?.clientMetadata?.instanceId
+          ? { client_instance_id: options.clientMetadata.instanceId }
+          : {}),
       }).toString(),
     });
     const body = yield* responseJsonEffect<{
@@ -1698,6 +1702,67 @@ it.layer(NodeServices.layer)("server router seam", (it) => {
     }).pipe(Effect.provide(NodeHttpServer.layerTest)),
   );
 
+  it.effect(
+    "collapses repeated token exchanges with one client instance onto a single session",
+    () =>
+      Effect.gen(function* () {
+        yield* buildAppUnderTest({
+          config: {
+            host: "0.0.0.0",
+          },
+        });
+
+        const ownerCookie = yield* getAuthenticatedSessionCookieHeader();
+        const pairingResponse = yield* HttpClient.post("/api/auth/pairing-token", {
+          headers: {
+            cookie: ownerCookie,
+          },
+          body: yield* HttpBody.json({}),
+        });
+        const pairingBody = (yield* pairingResponse.json) as {
+          readonly credential: string;
+        };
+
+        // Pairing credentials are one-time; the desktop bootstrap credential is
+        // long-lived, which is what repeated launches present.
+        const firstExchange = yield* exchangeAccessToken(defaultDesktopBootstrapToken, {
+          clientMetadata: {
+            label: "T3 Code Desktop",
+            deviceType: "desktop",
+            instanceId: "desktop-instance-1",
+          },
+        });
+        const secondExchange = yield* exchangeAccessToken(defaultDesktopBootstrapToken, {
+          clientMetadata: {
+            label: "T3 Code Desktop",
+            deviceType: "desktop",
+            instanceId: "desktop-instance-1",
+          },
+        });
+
+        const clientsResponse = yield* HttpClient.get("/api/auth/clients", {
+          headers: {
+            cookie: ownerCookie,
+          },
+        });
+        const clients = (yield* clientsResponse.json) as ReadonlyArray<{
+          readonly current: boolean;
+          readonly client: {
+            readonly label?: string;
+            readonly instanceId?: string;
+          };
+        }>;
+        const instanceSessions = clients.filter(
+          (client) => client.client.instanceId === "desktop-instance-1",
+        );
+
+        assert.equal(firstExchange.response.status, 200);
+        assert.equal(secondExchange.response.status, 200);
+        assert.equal(clientsResponse.status, 200);
+        assert.equal(instanceSessions.length, 1);
+      }).pipe(Effect.provide(NodeHttpServer.layerTest)),
+  );
+
   it.effect(
     "exchanges a bootstrap credential for a DPoP-bound access token without bearer downgrade",
     () =>
diff --git a/apps/web/src/connection/platform.ts b/apps/web/src/connection/platform.ts
index c7652136f..98b6d4044 100644
--- a/apps/web/src/connection/platform.ts
+++ b/apps/web/src/connection/platform.ts
@@ -21,7 +21,10 @@ import {
   PrimaryConnectionTarget,
   Wakeups,
 } from "@t3tools/client-runtime/connection";
-import { bootstrapRemoteBearerSession } from "@t3tools/client-runtime/authorization";
+import {
+  bootstrapRemoteBearerSession,
+  readOrCreateClientInstanceId,
+} from "@t3tools/client-runtime/authorization";
 import { fetchRemoteEnvironmentDescriptor } from "@t3tools/client-runtime/environment";
 import { managedRelayAccountChanges, managedRelaySessionAtom } from "@t3tools/client-runtime/relay";
 import { EnvironmentRpcRequestObserver } from "@t3tools/client-runtime/rpc";
@@ -50,6 +53,7 @@ import {
 } from "../environments/primary/target";
 import { clearComposerDraftsEnvironment } from "../composerDraftStore";
 import { isHostedStaticApp } from "../hostedPairing";
+import { randomUUID } from "../lib/utils";
 import { appAtomRegistry } from "../rpc/atomRegistry";
 import { acknowledgeRpcRequest, trackRpcRequestSent } from "../rpc/requestLatencyState";
 import {
@@ -120,9 +124,21 @@ function clientMetadata() {
     label: desktop ? "T3 Code Desktop" : "T3 Code Web",
     deviceType: "desktop" as const,
     ...(platform === "" ? {} : { os: platform }),
+    instanceId: clientInstanceId(),
   };
 }
 
+// Persisted per browser profile (Electron renderers included) so repeated
+// bootstraps reuse one authorized-client session instead of adding a row per
+// reload.
+function clientInstanceId(): string {
+  return readOrCreateClientInstanceId({
+    read: (key) => globalThis.localStorage?.getItem(key) ?? null,
+    write: (key, value) => globalThis.localStorage?.setItem(key, value),
+    createId: randomUUID,
+  });
+}
+
 function sshPreparationError(cause: unknown) {
   const message = cause instanceof Error ? cause.message : String(cause);
   if (message.toLowerCase().includes("cancel")) {
diff --git a/docs/internals/environment-auth.md b/docs/internals/environment-auth.md
index 5f4f5b6e9..9af8d6fb8 100644
--- a/docs/internals/environment-auth.md
+++ b/docs/internals/environment-auth.md
@@ -50,11 +50,23 @@ requested_token_type=urn:ietf:params:oauth:token-type:access_token
 scope=orchestration:read orchestration:operate terminal:operate review:write relay:read
 ```
 
-Clients may additionally submit `client_label`, `client_device_type`, and
-`client_os` extension parameters so the authorized-clients UI can identify the
-device that established the session. These are presentation hints only; the
-environment derives transport metadata such as IP address and user agent from
-the request and does not use these fields for authorization.
+Clients may additionally submit `client_label`, `client_device_type`,
+`client_os`, and `client_instance_id` extension parameters so the
+authorized-clients UI can identify the device that established the session.
+These are presentation hints only; the environment derives transport metadata
+such as IP address and user agent from the request and does not use these
+fields for authorization.
+
+`client_instance_id` is a stable per-install identifier. When it is present on
+a bearer exchange, issuance collapses onto the client's existing session: a
+compatible active session for the same subject, method, and instance id has its
+expiry extended and a fresh token is signed against it, so app relaunches and
+window reloads do not accumulate authorized-client rows. If no compatible
+session exists (for example when requested scopes widen), prior sessions for
+that instance are revoked before the replacement is issued. DPoP exchanges are
+exempt because their key thumbprint is not persisted, so their sessions cannot
+be safely reused. Issuance also prunes sessions whose rows have expired or been
+revoked.
 
 The response has the token-exchange shape:
 
diff --git a/packages/client-runtime/src/authorization/clientInstanceId.ts b/packages/client-runtime/src/authorization/clientInstanceId.ts
new file mode 100644
index 000000000..4f50cfafb
--- /dev/null
+++ b/packages/client-runtime/src/authorization/clientInstanceId.ts
@@ -0,0 +1,20 @@
+// Clients present a stable per-install instance id when exchanging bootstrap
+// credentials, letting the server collapse repeated bootstraps (app relaunches,
+// window reloads) onto one authorized-client session instead of accumulating a
+// row per launch.
+
+export const CLIENT_INSTANCE_ID_STORAGE_KEY = "t3.clientInstanceId";
+
+export function readOrCreateClientInstanceId(input: {
+  readonly read: (key: string) => string | null | undefined;
+  readonly write: (key: string, value: string) => void;
+  readonly createId: () => string;
+}): string {
+  const stored = input.read(CLIENT_INSTANCE_ID_STORAGE_KEY);
+  if (typeof stored === "string" && stored.trim() !== "") {
+    return stored;
+  }
+  const created = input.createId();
+  input.write(CLIENT_INSTANCE_ID_STORAGE_KEY, created);
+  return created;
+}
diff --git a/packages/client-runtime/src/authorization/index.ts b/packages/client-runtime/src/authorization/index.ts
index 6236b5922..4bc82c056 100644
--- a/packages/client-runtime/src/authorization/index.ts
+++ b/packages/client-runtime/src/authorization/index.ts
@@ -1,4 +1,5 @@
 export * from "./remote.ts";
+export * from "./clientInstanceId.ts";
 export {
   type AuthorizedRemoteEnvironment,
   type RelayEnvironmentAuthorization,
diff --git a/packages/client-runtime/src/authorization/remote.ts b/packages/client-runtime/src/authorization/remote.ts
index 69c157d0e..b0197a819 100644
--- a/packages/client-runtime/src/authorization/remote.ts
+++ b/packages/client-runtime/src/authorization/remote.ts
@@ -30,6 +30,7 @@ const clientMetadataTokenExchangeFields = (
   ...(clientMetadata?.label ? { client_label: clientMetadata.label } : {}),
   ...(clientMetadata?.deviceType ? { client_device_type: clientMetadata.deviceType } : {}),
   ...(clientMetadata?.os ? { client_os: clientMetadata.os } : {}),
+  ...(clientMetadata?.instanceId ? { client_instance_id: clientMetadata.instanceId } : {}),
 });
 
 export const exchangeRemoteDpopAccessToken = Effect.fn(
diff --git a/packages/contracts/src/auth.ts b/packages/contracts/src/auth.ts
index 70b289975..2c885f22a 100644
--- a/packages/contracts/src/auth.ts
+++ b/packages/contracts/src/auth.ts
@@ -169,6 +169,10 @@ export const AuthClientPresentationMetadata = Schema.Struct({
   label: Schema.optionalKey(TrimmedNonEmptyString),
   deviceType: Schema.optionalKey(AuthClientMetadataDeviceType),
   os: Schema.optionalKey(TrimmedNonEmptyString),
+  // Stable per-install identifier. Lets the server collapse repeated
+  // bootstraps from the same client onto one session instead of accumulating
+  // a row per launch.
+  instanceId: Schema.optionalKey(TrimmedNonEmptyString),
 });
 export type AuthClientPresentationMetadata = typeof AuthClientPresentationMetadata.Type;
 
@@ -181,6 +185,7 @@ export const AuthTokenExchangeRequest = Schema.Struct({
   client_label: Schema.optionalKey(TrimmedNonEmptyString),
   client_device_type: Schema.optionalKey(AuthClientMetadataDeviceType),
   client_os: Schema.optionalKey(TrimmedNonEmptyString),
+  client_instance_id: Schema.optionalKey(TrimmedNonEmptyString),
 }).pipe(HttpApiSchema.asFormUrlEncoded());
 export type AuthTokenExchangeRequest = typeof AuthTokenExchangeRequest.Type;
 
@@ -225,6 +230,7 @@ export const AuthClientMetadata = Schema.Struct({
   deviceType: AuthClientMetadataDeviceType,
   os: Schema.optionalKey(TrimmedNonEmptyString),
   browser: Schema.optionalKey(TrimmedNonEmptyString),
+  instanceId: Schema.optionalKey(TrimmedNonEmptyString),
 });
 export type AuthClientMetadata = typeof AuthClientMetadata.Type;

```
