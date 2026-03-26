FROM postgres:16-alpine
COPY load-seeds.sh /load-seeds.sh
RUN chmod +x /load-seeds.sh
ENTRYPOINT ["/load-seeds.sh"]
