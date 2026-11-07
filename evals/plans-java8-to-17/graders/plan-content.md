---
type: llm
focus: { source: file, path: .java-upgrade/plan.md }
---
PASS only if the plan:
- goes through Java 11 before 17 (two hops, or one step that applies both hop references in order);
- names the JAXB (javax.xml.bind) removal with a dependency fix, and the Nashorn script engine removal;
- lists obsolete JVM flags from run.sh (CMS, PrintGCDetails/PrintGCDateStamps/Xloggc, MaxPermSize) with replacements;
- bumps maven-compiler-plugin 3.8.1 and maven-surefire-plugin 2.22.2;
- marks modernization (records, pattern matching) as optional / not opted in.
FAIL if it recommends preview features or edits that were already applied.
