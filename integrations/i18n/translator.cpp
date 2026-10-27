#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QMap>
#include <QObject>
#include <QQmlEngine>
#include <QQmlExtensionPlugin>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTimer>
#include <QTranslator>
#include <QVariantList>

class LanguageController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString language READ language NOTIFY languageChanged)
    Q_PROPERTY(QString selectedLanguage READ selectedLanguage NOTIFY languageChanged)
    Q_PROPERTY(QString region READ region NOTIFY languageChanged)
    Q_PROPERTY(QVariantList languages READ languages CONSTANT)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
public:
    explicit LanguageController(QQmlEngine *engine) : QObject(engine), m_engine(engine) {
        m_directory = qEnvironmentVariable("SPECTRUM_TRANSLATIONS_DIR", "/usr/share/spectrumos/translations");
        m_preference = qEnvironmentVariable("SPECTRUM_LANGUAGE_FILE",
            QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/spectrumos/language.json");
        m_systemFile = qEnvironmentVariable("SPECTRUM_SYSTEM_LOCALE_FILE", "/etc/locale.conf");
        QFile registry(m_directory + "/languages.json");
        if (registry.open(QIODevice::ReadOnly)) {
            for (const auto value : QJsonDocument::fromJson(registry.readAll()).array())
                m_languages.append(value.toObject().toVariantMap());
        }
        if (m_english.load(m_directory + "/spectrum_en_US.qm")) QCoreApplication::installTranslator(&m_english);
        connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this] { schedule(); });
        connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] { schedule(); });
        m_reload.setSingleShot(true);
        m_reload.setInterval(30);
        connect(&m_reload, &QTimer::timeout, this, &LanguageController::reload);
        reload();
    }
    ~LanguageController() override {
        QCoreApplication::removeTranslator(&m_translator);
        QCoreApplication::removeTranslator(&m_english);
    }
    QString language() const { return m_language; }
    QString selectedLanguage() const { return m_selected; }
    QString region() const { return m_region; }
    QString error() const { return m_error; }
    QVariantList languages() const { return m_languages; }

    Q_INVOKABLE bool selectLanguage(const QString &value) {
        bool known = value == "system";
        for (const auto &row : m_languages) known |= row.toMap().value("id").toString() == value;
        if (!known) return fail("Choose a supported interface language");
        const QString parent = QFileInfo(m_preference).absolutePath();
        if (!QDir().mkpath(parent)) return fail("Could not create language settings directory");
        QSaveFile file(m_preference);
        if (!file.open(QIODevice::WriteOnly)) return fail("Could not save interface language");
        file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
        const auto content = QJsonDocument(QJsonObject{{"schema", 1}, {"language", value}}).toJson();
        if (file.write(content) != content.size() || !file.commit()) return fail("Could not save interface language");
        m_error.clear(); emit errorChanged(); reload(); return true;
    }

    Q_INVOKABLE void reload() {
        watch();
        QJsonObject settings;
        QFile file(m_preference);
        if (file.open(QIODevice::ReadOnly)) {
            if (file.size() > 8192) return;
            QJsonParseError error;
            const auto document = QJsonDocument::fromJson(file.readAll(), &error);
            if (error.error != QJsonParseError::NoError || !document.isObject()) return;
            settings = document.object();
        }
        QString system = qEnvironmentVariable("LC_MESSAGES", qEnvironmentVariable("LANG", "en_US"));
        QString region = system;
        QFile locale(m_systemFile);
        if (locale.open(QIODevice::ReadOnly)) {
            QMap<QString, QString> values;
            for (const auto &line : QString::fromUtf8(locale.readAll()).split('\n')) {
                const auto equal = line.indexOf('=');
                if (equal > 0) values[line.left(equal).trimmed()] = line.mid(equal + 1).trimmed().remove('"').remove('\'');
            }
            system = values.value("LC_MESSAGES", values.value("LANG", system));
            region = values.value("LC_TIME", values.value("LANG", region));
        }
        QString selected = settings.value("language").toString("system");
        QString desired = resolve(selected == "system" ? system : selected);
        region = QLocale(region).name();
        if (desired == m_language && selected == m_selected && region == m_region) return;
        QCoreApplication::removeTranslator(&m_translator);
        if (desired != "en_US") {
            if (!m_translator.load(m_directory + "/spectrum_" + desired + ".qm")) desired = "en_US";
            else QCoreApplication::installTranslator(&m_translator);
        }
        m_language = desired; m_selected = selected; m_region = region;
        QLocale::setDefault(QLocale(region));
        m_engine->setUiLanguage(desired);
        emit languageChanged();
        // Recalcula los textos sin reconstruir ventanas, campos ni temporizadores activos.
        QTimer::singleShot(0, this, [this] { m_engine->retranslate(); });
    }
signals:
    void languageChanged();
    void errorChanged();
private:
    bool fail(const QString &message) { m_error = message; emit errorChanged(); return false; }
    QString resolve(QString locale) const {
        locale = locale.section('.', 0, 0).section('@', 0, 0).replace('-', '_');
        for (const auto &row : m_languages)
            if (row.toMap().value("id").toString() == locale) return locale;
        for (const auto &row : m_languages)
            if (row.toMap().value("language").toString() == locale.section('_', 0, 0)) return row.toMap().value("id").toString();
        return "en_US";
    }
    void schedule() { m_reload.start(); }
    void watch() {
        QStringList paths{m_preference, QFileInfo(m_preference).absolutePath(),
            m_systemFile, QFileInfo(m_systemFile).absolutePath()};
        const QString parent = QFileInfo(QFileInfo(m_preference).absolutePath()).absolutePath();
        paths.append(parent);
        for (const auto &path : paths)
            if (QFileInfo::exists(path) && !m_watcher.files().contains(path) && !m_watcher.directories().contains(path))
                m_watcher.addPath(path);
    }
    QQmlEngine *m_engine;
    QTranslator m_translator;
    QTranslator m_english;
    QFileSystemWatcher m_watcher;
    QTimer m_reload;
    QVariantList m_languages;
    QString m_directory, m_preference, m_systemFile, m_language, m_selected, m_region, m_error;
};

class SpectrumI18nPlugin : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)
public:
    void registerTypes(const char *uri) override {
        qmlRegisterSingletonType<LanguageController>(uri, 1, 0, "Translator",
            [](QQmlEngine *engine, QJSEngine *) -> QObject * { return new LanguageController(engine); });
    }
};
#include "translator.moc"
