package io.github.yoyote84.flipdexos.shell;
interface IFlipdexShellService {
    // Reserved Shizuku UserService destroy transaction.
    void destroy() = 16777114;
    int getUid() = 1;
    String getProperty(String name) = 2;
    String getGlobalSetting(String name) = 3;
    int putGlobalSetting(String name, String value) = 4;
    int deleteGlobalSetting(String name) = 5;
}
