# Single Responsibility Principle (SRP)

Contents: rule · example · smells · when not to split · checklist.

## Rule

A class has one reason to change. Martin (2014) defines a reason as a person or a tightly coupled group of people who ask for changes: "Gather together the things that change for the same reasons. Separate those things that change for different reasons."

Count the groups who would ask for edits to the class: product owners, the security team, DBAs, report consumers. One group is fine at any size. Two groups mean two classes, split along the line between them.

## Example

Email changes belong to the account feature; access rules belong to security. The access check sits behind an interface the service receives, so security can change its rules without touching the service and tests can pass a stub.

<!-- compile: jdk=16 -->
```java
import java.util.Objects;

record User(long id, String email) {
    User withEmail(String newEmail) {
        return new User(id, newEmail);
    }
}

interface AccessPolicy {
    boolean canChangeEmail(User user);
}

interface UserRepository {
    void save(User user);
}

static final class UserSettingService {
    private final AccessPolicy accessPolicy;
    private final UserRepository users;

    UserSettingService(AccessPolicy accessPolicy, UserRepository users) {
        this.accessPolicy = Objects.requireNonNull(accessPolicy);
        this.users = Objects.requireNonNull(users);
    }

    void changeEmail(User user, String newEmail) {
        if (!accessPolicy.canChangeEmail(user)) {
            throw new SecurityException("user " + user.id() + " may not change email");
        }
        users.save(user.withEmail(newEmail));
    }
}
```

Below release 16, write `User` as a final class with final fields. The source post made the policy a static method, which cannot be swapped (errata.md).

## Smells

- One class mixes code that different groups own: formatting, business rules, persistence, transport.
- Tests need large setup or many mocks, and each test uses a few of them.
- The constructor takes many collaborators (more than about five), and methods use disjoint subsets of them.
- Names like `*Manager`, `*Helper`, `*Util`, or names joined by `And`.
- Unrelated features keep landing in the same file. Churn shows it:

  ```bash
  git -C <root> log --since=1.year --format= --name-only -- '*.java' | sort | uniq -c | sort -rn | head -20
  ```

## When not to split

- All the code changes for one group. A long class with one owner is cohesive; splitting it scatters each change across files.
- One method per class is not SRP. Split by owner, not by method count.
- Records and enums that carry data plus small derived values (`withEmail`, `isOverdue`) keep that behavior.

## Checklist

1. List who asks for changes to the class. One group: stop.
2. Group fields and methods by owner. Methods that touch fields from two groups mark the seam.
3. Move each group into its own class; the original receives the new classes through its constructor.
4. Keep behavior and public API unchanged; run tests after each move.
