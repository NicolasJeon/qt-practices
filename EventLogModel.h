#pragma once

#include <QAbstractListModel>
#include <QList>
#include <QString>
#include <qqmlregistration.h>

class EventLogModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int maxCount READ maxCount WRITE setMaxCount NOTIFY maxCountChanged FINAL)

public:
    enum EventLogRoles {
        TimeRole = Qt::UserRole + 1,
        LevelRole,
        MessageRole
    };
    Q_ENUM(EventLogRoles)

    explicit EventLogModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int maxCount() const;
    void setMaxCount(int maxCount);

    Q_INVOKABLE void addEvent(int level, const QString &message);
    Q_INVOKABLE void clear();

signals:
    void maxCountChanged();

private:
    struct EventLogItem {
        QString time;
        int level;
        QString message;
    };

    void trimToMaxCount();

    QList<EventLogItem> m_items;
    int m_maxCount = 8;
};
