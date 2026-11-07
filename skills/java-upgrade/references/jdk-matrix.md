# JDK 8 → 27 fact matrix

Single source of truth for feature status and minimum JDK. Other skills link here instead of restating versions. Facts checked against openjdk.org JEP and release pages (JDK 25, 26, 27 pages fetched 2026-11-07).

Contents: release line · final language/API features · preview and incubator status · removals and breaking changes · JVM flag changes · corrections to common wrong advice · sources.

## Release line

| JDK | GA | LTS | Notes |
|-----|----|-----|-------|
| 8 | 2014-03 | yes | Baseline for legacy code |
| 11 | 2018-09 | yes | Java EE / CORBA removed |
| 17 | 2021-09 | yes | Strong encapsulation enforced |
| 21 | 2023-09 | yes | Virtual threads, pattern switch, record patterns |
| 25 | 2025-09-16 | yes | Current LTS. Scoped values, flexible constructors, module imports, compact source files |
| 26 | 2026-03-17 | no | Final-field mutation warnings, Applet API removed, HTTP/3 client |
| 27 | 2026-09-15 | no | Latest GA. G1 default everywhere, compact object headers default |

Hop strategy: step through LTS releases (8 → 11 → 17 → 21 → 25), then 25 → 27 only when the user targets a non-LTS release. 26 is a stop only when the user asks for it.

## Final language and API features (minimum JDK)

| Feature | JEP | Final in | Skill reference |
|---------|-----|----------|-----------------|
| `List.of` / `Set.of` / `Map.of` (immutable, reject null) | 269 | 9 | collections-streams.md |
| Private interface methods; `_` no longer an identifier | 213 | 9 | language-misc.md |
| `var` for locals | 286 | 10 | language-misc.md |
| `List.copyOf`, `Collectors.toUnmodifiable*`, `Optional.orElseThrow()` | — | 10 | collections-streams.md |
| `String.isBlank/strip/lines/repeat`, `Files.readString/writeString`, `Predicate.not` | — | 11 | text-and-strings.md |
| `java.net.http.HttpClient` | 321 | 11 | language-misc.md |
| `var` in lambda parameters | 323 | 11 | language-misc.md |
| Launch single-file source programs | 330 | 11 | language-misc.md |
| `String.indent/transform`, `Collectors.teeing` | — | 12 | collections-streams.md |
| Switch expressions, arrow labels, `yield` | 361 | 14 | patterns-switch.md |
| Helpful NullPointerException messages (on by default) | 358 | 14 (default 15) | — |
| Text blocks; `String.formatted`, `stripIndent`, `translateEscapes` | 378 | 15 | text-and-strings.md |
| Records | 395 | 16 | records-sealed.md |
| Pattern matching for `instanceof` | 394 | 16 | patterns-switch.md |
| `Stream.toList()` (unmodifiable) | — | 16 | collections-streams.md |
| Sealed classes and interfaces | 409 | 17 | records-sealed.md |
| `RandomGenerator` API | 356 | 17 | — |
| Context-specific deserialization filters | 415 | 17 | (secure-coding serialization.md) |
| UTF-8 default charset | 400 | 18 | (migrate 17-to-21.md) |
| `@snippet` in Javadoc | 413 | 18 | language-misc.md |
| Virtual threads | 444 | 21 | concurrency.md |
| Pattern matching for `switch` | 441 | 21 | patterns-switch.md |
| Record patterns | 440 | 21 | patterns-switch.md |
| Sequenced collections (`getFirst/getLast/reversed`) | 431 | 21 | collections-streams.md |
| KEM API (`javax.crypto.KEM`, DHKEM only) | 452 | 21 | — |
| Unnamed variables and patterns `_` | 456 | 22 | patterns-switch.md |
| Foreign Function and Memory API | 454 | 22 | (migrate 21-to-25.md) |
| Launch multi-file source programs | 458 | 22 | language-misc.md |
| `jdk.xml.dtd.support` system property (allow/ignore/deny DTDs in all JDK XML parsers) | — | 22 | (secure-coding injection.md) |
| Built-in XML catalog; `jdk.xml.jdkcatalog.resolve=strict` rejects unresolved external references | — | 22 | (secure-coding injection.md) |
| Markdown documentation comments `///` | 467 | 23 | language-misc.md |
| `conf/jaxp-strict.properties.template` (on 25–27 differs from the default only in `jdkcatalog.resolve=strict`) | — | 23 | (secure-coding injection.md) |
| Stream gatherers | 485 | 24 | collections-streams.md |
| Class-File API (`java.lang.classfile`) | 484 | 24 | language-misc.md |
| ML-KEM / ML-DSA post-quantum algorithms | 496 / 497 | 24 | — |
| `synchronized` no longer pins virtual threads | 491 | 24 | concurrency.md |
| Scoped values | 506 | 25 | concurrency.md |
| Module import declarations (`import module java.base;`) | 511 | 25 | language-misc.md |
| Compact source files and instance `main` methods, `java.lang.IO` | 512 | 25 | language-misc.md |
| Flexible constructor bodies (statements before `super(...)`) | 513 | 25 | language-misc.md |
| Key Derivation Function API | 510 | 25 | — |
| HTTP/3 in `HttpClient` (opt-in `HttpClient.Version.HTTP_3`) | 517 | 26 | language-misc.md |

## Preview and incubator status (as of JDK 27)

Preview features compile only with `--enable-preview` on exactly one JDK release and may change or disappear. Default: never adopt. See `java-modernize/references/preview-features.md`.

| Feature | History | Status in 27 |
|---------|---------|--------------|
| Primitive types in patterns, `instanceof`, `switch` | 455 (23), 488 (24), 507 (25), 530 (26), 532 (27) | 5th preview |
| Structured concurrency | 428/437 incubator; 453 (21), 462, 480, 499, 505 (25, redesigned: `StructuredTaskScope.open(Joiner)`), 525 (26), 533 (27, API changed again) | 7th preview |
| Lazy constants (was `StableValue`) | 502 (25), 526 (26, renamed), 531 (27) | 3rd preview |
| PEM encodings | 470 (25), 524 (26), 538 (27) | 3rd preview |
| Vector API (`jdk.incubator.vector`) | 338 (16) … 537 (27) | 12th incubator |
| String templates | 430 (21), 459 (22); 465 withdrawn | **Removed in 23. Never use** |
| Derived record creation (`with` expressions) | 468 | **Candidate, never shipped** |
| Value classes (Valhalla, JEP 401) | — | Not in any JDK through 27 |

## Removals and breaking changes by release

| JDK | Change | JEP | Signal id (scan.sh) | Fix in |
|-----|--------|-----|---------------------|--------|
| 9 | Module system; internal APIs encapsulated (`sun.*` hidden at compile time with `--release`) | 260, 261 | sun-internal | migrate 8-to-11.md |
| 9 | `rt.jar` / `tools.jar` removed | 220 | tools-jar | migrate 8-to-11.md |
| 9 | Version string `9`, `17.0.2` (no `1.x`) | 223 | java-version-parse | migrate 8-to-11.md |
| 9 | `sun.misc.BASE64Encoder/Decoder` removed | — | sun-misc-base64 | migrate 8-to-11.md |
| 9 | Unified JVM and GC logging; old GC log flags error or warn | 158, 271 | gc-log-flags | migrate 8-to-11.md |
| 11 | Java EE and CORBA modules removed (JAXB, JAX-WS, JAF, common annotations, JTA, CORBA) | 320 | jaxb, jaxws, javax-activation, javax-annotation-ee, javax-transaction-ee, corba | migrate 8-to-11.md |
| 11 | JavaFX unbundled from Oracle JDK | — | javafx | migrate 8-to-11.md |
| 13 | Old doclet API `com.sun.javadoc` removed | — | javadoc-old-doclet | migrate 11-to-17.md |
| 14 | CMS GC removed | 363 | cms-gc | migrate 11-to-17.md |
| 14 | Pack200 removed | 367 | pack200 | migrate 11-to-17.md |
| 15 | Nashorn removed | 372 | nashorn | migrate 11-to-17.md |
| 16 | Wrapper class constructors deprecated for removal | 390 | new-wrapper | migrate 11-to-17.md |
| 16 / 17 | Strong encapsulation: `--illegal-access` default deny (16), option ignored (17); deep reflection into JDK needs `--add-opens` | 396, 403 | deep-reflection, illegal-access | migrate 11-to-17.md |
| 17 | RMI activation removed; Security Manager deprecated for removal; Applet API deprecated for removal | 407, 411, 398 | rmi-activation | migrate 11-to-17.md |
| 18 | UTF-8 default charset | 400 | default-charset | migrate 17-to-21.md |
| 18 | Finalization deprecated for removal | 421 | finalize | migrate 17-to-21.md |
| 18 | Biased locking removed (flag obsolete) | 374 | biased-locking | migrate 17-to-21.md |
| 20 | `Thread.stop/suspend/resume` throw `UnsupportedOperationException`; `suspend/resume` absent by 25, `stop` absent in 27 | — | (jdeprscan) | migrate 17-to-21.md |
| 21 | Dynamic agent loading warns (Mockito inline, Byte Buddy agent) | 451 | mockito-agent | migrate 17-to-21.md, java-build |
| 21 | Sequenced collections can clash with custom collection subclasses | 431 | sequenced-conflict | migrate 17-to-21.md |
| 23 | `sun.misc.Unsafe` memory-access methods deprecated for removal; 24 warns at runtime | 471, 498 | unsafe-memory | migrate 21-to-25.md |
| 23 | javac stops running annotation processors found on the class path without explicit configuration (change phased 21–23) | — | lombok, mapstruct | java-build |
| 23 | String templates preview removed | 465 | string-templates | migrate 21-to-25.md |
| 24 | Security Manager permanently disabled | 486 | security-manager | migrate 21-to-25.md |
| 24 | JNI use warns; `--enable-native-access` | 472 | jni | migrate 21-to-25.md |
| 24 | Non-generational ZGC removed; `ZGenerational` obsolete | 490 | zgenerational | migrate 21-to-25.md |
| 24 | JAXP processing limits lowered (entity expansions 64000 → 2500, attributes per element 10000 → 200, …); large DTDs fail with `JAXP0001xxxx` | — | — | migrate 21-to-25.md |
| 25 | 32-bit x86 port removed | 503 | — | migrate 21-to-25.md |
| 25 | XSLT extension functions off by default (`jdk.xml.enableExtensionFunctions=false`) | — | — | migrate 21-to-25.md |
| 25 | Structured concurrency preview redesigned (`ShutdownOnFailure` gone) | 505 | structured-concurrency-old | migrate 21-to-25.md |
| 26 | Reflective mutation of `final` fields warns (`deny` planned) | 500 | deep-reflection | migrate 25-to-27.md |
| 26 | Applet API removed | 504 | applet | migrate 25-to-27.md |
| 27 | G1 chosen in all environments (no automatic Serial GC in small containers) | 523 | — | migrate 25-to-27.md |
| 27 | Compact object headers on by default | 534 | — | migrate 25-to-27.md |
| 27 | TLS 1.3 offers hybrid X25519MLKEM768 first | 527 | — | migrate 25-to-27.md |

## JVM flag changes

| Flag | Status | Replacement |
|------|--------|-------------|
| `-XX:+PrintGCDetails`, `-XX:+PrintGCDateStamps`, `-Xloggc:` … | Replaced in 9 (several make the JVM refuse to start) | `-Xlog:gc*:file=gc.log:time,uptime:filecount=5,filesize=10m` |
| `-XX:MaxPermSize`, `-XX:PermSize` | Ignored since 8 | Drop; `-XX:MaxMetaspaceSize` only if needed |
| `-XX:+UseConcMarkSweepGC` | Removed 14 | G1 (default) or `-XX:+UseZGC` |
| `-XX:+AggressiveOpts`, `-XX:+UseParNewGC` | Expired | Drop |
| `--illegal-access=…` | Ignored since 17 | Targeted `--add-opens module/package=ALL-UNNAMED` |
| `-XX:+UseBiasedLocking` | Obsolete 18 | Drop |
| `-XX:+EnableDynamicAgentLoading` | 21+ escape hatch | Prefer `-javaagent:` at startup |
| `-XX:+ZGenerational` / `-XX:-ZGenerational` | Valid 21–23 only; obsolete 24 | `-XX:+UseZGC` alone (generational) |
| `-Djava.security.manager=…` | Startup error from 24 | Remove |
| `--enable-native-access=ALL-UNNAMED` | Needed from 24 to silence JNI/FFM warnings | Or manifest `Enable-Native-Access: ALL-UNNAMED` |
| `--sun-misc-unsafe-memory-access=allow` | 24+ stopgap | Migrate to VarHandle / FFM |
| `--enable-final-field-mutation=ALL-UNNAMED` | 26+ stopgap | Stop mutating finals reflectively |
| `-XX:+UseCompactObjectHeaders` | Opt-in 25, default 27 | `-XX:-UseCompactObjectHeaders` to opt out |
| `-XX:AOTCacheOutput=app.aot` / `-XX:AOTCache=app.aot` | 25+ (JEPs 483, 514, 515; 516 any GC in 26) | Startup optimization, optional |

## Corrections to common wrong advice

These claims appear in older guides (including the rule files this plugin was built from). Do not repeat them.

| Wrong | Right |
|-------|-------|
| String templates (`STR."…"`) are usable from 21 | Preview in 21–22 only, withdrawn, removed in 23 |
| `-XX:+ZGenerational` enables generational ZGC | Only on 21–23; obsolete from 24, generational is the only mode |
| `new StructuredTaskScope.ShutdownOnFailure()` | Gone in 25; `StructuredTaskScope.open(Joiner…)`; still preview through 27 and changed again in 27 |
| ML-KEM via `KEM.getInstance("ML-KEM")` on 21 | 21 has the KEM API with DHKEM only; ML-KEM arrived in 24 |
| `person with { age = 30; }` | JEP 468 never shipped |
| Scoped values need `--enable-preview` | Final in 25 |
| `requires jdk.unsupported` for JNI | `jdk.unsupported` exposes `sun.misc.Unsafe`/`Signal`; JNI needs `--enable-native-access` |
| Remove explicit `StandardCharsets.UTF_8` since UTF-8 is the default | Keep it: portable to older JDKs, immune to `-Dfile.encoding=COMPAT`, documents intent |
| `case default ->` in pattern switch | Final syntax is `default ->` (or `case null, default ->`) |

## Sources

- Release pages: <https://openjdk.org/projects/jdk/25/>, <https://openjdk.org/projects/jdk/26/>, <https://openjdk.org/projects/jdk/27/>
- JEP pages: `https://openjdk.org/jeps/<number>`
- Oracle migration guides: `https://docs.oracle.com/en/java/javase/<N>/migrate/index.html`
