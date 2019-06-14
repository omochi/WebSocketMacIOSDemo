export function map<T, U>(t: T | null, m: (t: T) => U): U | null {
    if (t != null) {
        return m(t)
    } else {
        return null;
    }
}