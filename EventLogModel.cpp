#include "EventLogModel.h"

#include <QTime>

EventLogModel::EventLogModel(QObject *parent)
    : QAbstractListModel(parent)
{
    m_items = {
        {QStringLiteral("13:00:00"), 0, QStringLiteral("Camera 01 stream connected")},
        {QStringLiteral("13:04:18"), 0, QStringLiteral("Camera 02 stream connected")},
        {QStringLiteral("13:12:43"), 1, QStringLiteral("Camera 03 signal unstable")}
    };
}

int EventLogModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;

    return m_items.size();
}

QVariant EventLogModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size())
        return {};

    const EventLogItem &item = m_items.at(index.row());

    switch (role) {
    case TimeRole:
        return item.time;
    case LevelRole:
        return item.level;
    case MessageRole:
        return item.message;
    default:
        return {};
    }
}

QHash<int, QByteArray> EventLogModel::roleNames() const
{
    return {
        {TimeRole, "time"},
        {LevelRole, "level"},
        {MessageRole, "message"}
    };
}

int EventLogModel::maxCount() const
{
    return m_maxCount;
}

void EventLogModel::setMaxCount(int maxCount)
{
    if (m_maxCount == maxCount)
        return;

    m_maxCount = maxCount;
    emit maxCountChanged();
    trimToMaxCount();
}

void EventLogModel::addEvent(int level, const QString &message)
{
    beginInsertRows(QModelIndex(), 0, 0);
    m_items.prepend({QTime::currentTime().toString(QStringLiteral("hh:mm:ss")), level, message});
    endInsertRows();

    trimToMaxCount();
}

void EventLogModel::clear()
{
    if (m_items.isEmpty())
        return;

    beginRemoveRows(QModelIndex(), 0, m_items.size() - 1);
    m_items.clear();
    endRemoveRows();
}

void EventLogModel::trimToMaxCount()
{
    if (m_maxCount < 0 || m_items.size() <= m_maxCount)
        return;

    beginRemoveRows(QModelIndex(), m_maxCount, m_items.size() - 1);
    m_items.erase(m_items.begin() + m_maxCount, m_items.end());
    endRemoveRows();
}
