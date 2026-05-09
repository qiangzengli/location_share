package com.locationshare.backend.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;

import java.io.Serializable;
import java.util.Objects;

@Embeddable
public class ParticipantLocationId implements Serializable {

    @Column(name = "group_id", nullable = false, length = 128)
    private String groupId;

    @Column(name = "participant_id", nullable = false, length = 128)
    private String participantId;

    protected ParticipantLocationId() {
    }

    public ParticipantLocationId(String groupId, String participantId) {
        this.groupId = groupId;
        this.participantId = participantId;
    }

    public String getGroupId() {
        return groupId;
    }

    public void setGroupId(String groupId) {
        this.groupId = groupId;
    }

    public String getParticipantId() {
        return participantId;
    }

    public void setParticipantId(String participantId) {
        this.participantId = participantId;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) {
            return true;
        }
        if (o == null || getClass() != o.getClass()) {
            return false;
        }
        ParticipantLocationId that = (ParticipantLocationId) o;
        return Objects.equals(groupId, that.groupId) && Objects.equals(participantId, that.participantId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(groupId, participantId);
    }
}
