package com.locationshare.backend.repository;

import com.locationshare.backend.domain.ParticipantLocationId;
import com.locationshare.backend.domain.ParticipantLocationRow;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ParticipantLocationRepository extends JpaRepository<ParticipantLocationRow, ParticipantLocationId> {

    List<ParticipantLocationRow> findByIdGroupIdOrderByUpdatedAtDesc(String groupId);
}
